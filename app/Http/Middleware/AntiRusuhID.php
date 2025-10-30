<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Pterodactyl\Models\Server;

class AntiRusuhID
{
    public function handle(Request $request, Closure $next)
    {
        $superAdmin = env('ANTI_RUSUH_SUPER_ADMIN_ID', '1');
        $allowedCsv = env('ANTI_RUSUH_ALLOWED_ADMIN_IDS', '');
        $botApiToken = env('ANTI_RUSUH_BOT_API_TOKEN');

        $allowedIds = array_filter(array_map('trim', explode(',', $allowedCsv)));
        $user = $request->user();
        $path = $request->getPathInfo();
        $method = strtoupper($request->getMethod());

        // Bot/API request: izinkan buat server
        if (is_null($user) && $this->isBotRequestAllowed($request, $botApiToken)) {
            if ($request->is('api/application/servers') && $method === 'POST') {
                return $next($request);
            }
        }

        // Super admin akses semua
        if (!is_null($user) && (string)$user->id === (string)$superAdmin) {
            return $next($request);
        }

        // Admin whitelist
        if (!is_null($user) && in_array((string)$user->id, $allowedIds, true)) {
            return $next($request);
        }

        // Blok akses server orang lain
        if ($this->isServerListPath($path) || ($this->isApiServersPath($path) && $method === 'GET')) {
            $this->logViolation($user, $request, 'Mencoba melihat daftar server');
            return $this->forbiddenResponse('Akses terlarang: melihat daftar server dilarang untuk admin biasa.');
        }

        if ($this->isServerDetailPath($path) || $this->isApiServerDetailPath($path)) {
            $identifier = $this->extractServerIdentifier($request);
            if (! $this->isServerOwnedByUser($identifier, $user)) {
                $this->logViolation($user, $request, "Mencoba melihat server bukan miliknya: " . ($identifier ?? 'unknown'));
                return $this->forbiddenResponse('Akses terlarang: melihat server orang lain dilarang.');
            }
        }

        // Blok update/delete user & server
        if ($this->isUserPath($path) && in_array($method, ['PUT','PATCH','DELETE','POST'])) {
            $this->logViolation($user, $request, 'Mencoba mengubah/hapus data user');
            return $this->forbiddenResponse('Akses terlarang: mengubah atau menghapus data pengguna dilarang.');
        }

        if ($this->isUserPath($path)) {
            $this->logViolation($user, $request, 'Mencoba melihat data user');
            return $this->forbiddenResponse('Akses terlarang: melihat data pengguna dilarang untuk admin biasa.');
        }

        if ($this->isServerPath($path) && in_array($method, ['PUT','PATCH','DELETE','POST'])) {
            $this->logViolation($user, $request, 'Mencoba mengubah/hapus server');
            return $this->forbiddenResponse('Akses terlarang: mengubah atau menghapus server dilarang.');
        }

        // Blok akses nests
        if ($this->isNestsPath($path)) {
            $this->logViolation($user, $request, 'Mencoba mengakses nests');
            return $this->forbiddenResponse('Akses terlarang: nests dilarang untuk admin biasa.');
        }

        // Blok akses settings
        if ($this->isSettingsPath($path)) {
            $this->logViolation($user, $request, 'Mencoba mengakses settings');
            return $this->forbiddenResponse('Akses terlarang: settings dilarang untuk admin biasa.');
        }

        return $next($request);
    }

    protected function isBotRequestAllowed(Request $request, $botApiToken)
    {
        if (empty($botApiToken)) return false;
        $header = $request->header('X-Bot-Token');
        if (!empty($header) && hash_equals($botApiToken, $header)) return true;
        $auth = $request->bearerToken();
        if (!empty($auth) && hash_equals($botApiToken, $auth)) return true;
        return false;
    }

    protected function isServerOwnedByUser($identifier, $user)
    {
        if (empty($identifier) || is_null($user)) return false;

        try {
            $server = null;
            if (class_exists(Server::class)) {
                if (Str::contains($identifier, '-')) {
                    $server = Server::where('uuid', $identifier)->first();
                }
                if (is_null($server)) {
                    $server = Server::where('id', $identifier)->orWhere('uuid', $identifier)->first();
                }
                if ($server) {
                    $ownerId = $server->owner_id ?? $server->user_id ?? $server->owner->id ?? null;
                    return (string)$ownerId === (string)$user->id;
                }
            }
        } catch (\Throwable $e) {
            Log::warning('AntiRusuh: gagal resolve server - ' . $e->getMessage());
            return false;
        }
        return false;
    }

    protected function extractServerIdentifier(Request $request)
    {
        $possibleParams = ['server','server_id','id','uuid'];
        foreach ($possibleParams as $p) {
            if ($request->route($p)) return $request->route($p);
            if ($request->input($p)) return $request->input($p);
        }
        $segments = array_values(array_filter(explode('/', $request->getPathInfo())));
        if (count($segments) > 0) {
            $last = end($segments);
            if (! in_array($last, ['servers','admin','api','application'])) return $last;
        }
        return null;
    }

    protected function isServerListPath($path) { return preg_match('#^/admin/servers(/|$)#',$path); }
    protected function isApiServersPath($path) { return preg_match('#^/api/application/servers(/|$)#',$path); }
    protected function isServerDetailPath($path) { return preg_match('#^/admin/servers/[^/]+#',$path); }
    protected function isApiServerDetailPath($path) { return preg_match('#^/api/application/servers/[^/]+#',$path); }
    protected function isUserPath($path) { return preg_match('#^(/admin/users|/api/application/users)(/|$)#',$path); }
    protected function isServerPath($path) { return preg_match('#^(/admin/servers|/api/application/servers)(/|$)#',$path); }
    protected function isNestsPath($path) { return preg_match('#^(/admin/nests|/api/application/nests)(/|$)#',$path); }
    protected function isSettingsPath($path) { return preg_match('#^(/admin/settings|/api/application/settings)(/|$)#',$path); }

    protected function forbiddenResponse($message='Forbidden')
    {
        $signature='Fitur anti rusuh aktif by Samz Market, jasa pasang? pv t.me/samznotfamous';
        $finalMessage = trim($message) ?: '';
        if (!empty($finalMessage)) $finalMessage .= ' - '.$signature;
        else $finalMessage = $signature;
        return response()->json(['error'=>'forbidden','message'=>$finalMessage], Response::HTTP_FORBIDDEN);
    }

    protected function logViolation($user, Request $request, $reason='')
    {
        try {
            $meta = [
                'user_id'=>$user->id ?? null,
                'ip'=>$request->ip(),
                'path'=>$request->getPathInfo(),
                'method'=>$request->method(),
                'reason'=>$reason,
            ];
            Log::warning('AntiRusuh violation',$meta);
        } catch (\Throwable $e) {}
    }
}
