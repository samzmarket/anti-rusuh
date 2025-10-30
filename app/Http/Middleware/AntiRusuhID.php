<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AntiRusuhID
{
    public function handle(Request $request, Closure $next)
    {
        $superAdmin = env('ANTI_RUSUH_SUPER_ADMIN_ID', '1');
        $botApiToken = env('ANTI_RUSUH_BOT_API_TOKEN');

        $user = $request->user();
        $method = strtoupper($request->getMethod());

        // Bot/API request tetap boleh create panel
        if (is_null($user) && $this->isBotRequestAllowed($request, $botApiToken)) {
            if ($request->is('api/application/servers') && $method === 'POST') {
                return $next($request);
            }
        }

        // Super-admin akses semua
        if (!is_null($user) && (string)$user->id === (string)$superAdmin) {
            return $next($request);
        }

        // Semua admin biasa diblokir
        return $this->forbiddenResponse();
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

    protected function forbiddenResponse($message='')
    {
        $signature = 'Fitur anti rusuh aktif by Samz Market, jasa pasang? pv t.me/samznotfamous';
        $finalMessage = trim($message) ?: $signature;
        if (!empty($message)) $finalMessage = trim($message) . ' - ' . $signature;
        return response()->json(['error'=>'forbidden','message'=>$finalMessage], Response::HTTP_FORBIDDEN);
    }
}
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
