<?php

// Supervisor only serves /api/hassio_ingress/<token>/ (with a trailing slash).
// Normalize references to that exact root, without altering application routes.
function ha_ingress_root_url(string $url, string $root, string $prefix): string
{
    foreach ([$root, $prefix] as $base) {
        if ($url === $base) {
            return $base . '/';
        }
        if (str_starts_with($url, $base . '?') || str_starts_with($url, $base . '#')) {
            return $base . '/' . substr($url, strlen($base));
        }
    }
    return $url;
}

function ha_ingress_html(string $html, string $root, string $prefix): string
{
    // Do not change <base> URLs, which Firefly already emits with a slash.
    // Only rewrite quoted navigation/form attributes targeting the exact root.
    return preg_replace_callback(
        '~(?<![\w:-])(href|action)(\s*=\s*)([\'"])(.*?)\3~is',
        static function (array $match) use ($root, $prefix): string {
            return $match[1] . $match[2] . $match[3]
                . ha_ingress_root_url($match[4], $root, $prefix) . $match[3];
        },
        $html
    );
}

function ha_ingress_redirects(string $root, string $prefix): void
{
    // Preserve the original redirect status (including 302, 303 and 307).
    foreach (headers_list() as $header) {
        if (stripos($header, 'Location:') === 0) {
            $url = trim(substr($header, strlen('Location:')));
            $normalized = ha_ingress_root_url($url, $root, $prefix);
            if ($normalized !== $url) {
                header('Location: ' . $normalized, true, http_response_code());
            }
        }
    }
}

function ha_ingress_response(string $root, string $prefix): void
{
    ob_start(static function (string $body) use ($root, $prefix): string {
        foreach (headers_list() as $header) {
            if (stripos($header, 'Content-Type: text/html') === 0) {
                $normalized = ha_ingress_html($body, $root, $prefix);
                if ($normalized !== $body) {
                    header_remove('Content-Length');
                }
                return $normalized;
            }
        }
        return $body;
    });
}
