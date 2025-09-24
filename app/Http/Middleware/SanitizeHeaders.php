<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class SanitizeHeaders
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);
        
        // Nettoyer les en-têtes de réponse
        $headers = $response->headers->all();
        foreach ($headers as $name => $values) {
            foreach ($values as $key => $value) {
                // Supprimer les nouvelles lignes
                $cleanValue = str_replace(["\r", "\n"], '', $value);
                $response->headers->set($name, $cleanValue, false);
            }
        }
        
        return $response;
    }
}