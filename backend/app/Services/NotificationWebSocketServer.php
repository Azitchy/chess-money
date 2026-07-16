<?php

namespace App\Services;

class NotificationWebSocketServer
{
    public function run(string $host = '127.0.0.1', int $wsPort = 8081, int $publishPort = 8082): void
    {
        if (! function_exists('stream_socket_server')) {
            throw new \RuntimeException('stream_socket_server is not available');
        }

        ignore_user_abort(true);
        set_time_limit(0);

        $wsServer = $this->createServer($host, $wsPort);
        $publishServer = $this->createServer($host, $publishPort);

        $clients = [];

        echo "Notification websocket server running on {$host}:{$wsPort}\n";
        echo "Publish endpoint listening on {$host}:{$publishPort}\n";

        while (true) {
            $read = [$wsServer, $publishServer];
            foreach ($clients as $client) {
                $read[] = $client['socket'];
            }

            $write = null;
            $except = null;
            if (@stream_select($read, $write, $except, 1) === false) {
                continue;
            }

            foreach ($read as $stream) {
                if ($stream === $wsServer) {
                    $client = @stream_socket_accept($wsServer, 0);
                    if ($client) {
                        stream_set_blocking($client, false);
                        $clients[(int) $client] = [
                            'socket' => $client,
                            'handshake' => false,
                            'buffer' => '',
                        ];
                    }
                    continue;
                }

                if ($stream === $publishServer) {
                    $publisher = @stream_socket_accept($publishServer, 0);
                    if ($publisher) {
                        $payload = trim((string) stream_get_contents($publisher));
                        if ($payload !== '') {
                            $this->handlePublishPayload($payload, $clients);
                        }
                        fclose($publisher);
                    }
                    continue;
                }

                $clientId = (int) $stream;
                if (! isset($clients[$clientId])) {
                    continue;
                }

                $chunk = @fread($stream, 8192);
                if ($chunk === '' || $chunk === false) {
                    if (feof($stream)) {
                        fclose($stream);
                        unset($clients[$clientId]);
                    }
                    continue;
                }

                if (! $clients[$clientId]['handshake']) {
                    $clients[$clientId]['buffer'] .= $chunk;
                    if (str_contains($clients[$clientId]['buffer'], "\r\n\r\n")) {
                        $this->finishHandshake($clients[$clientId]['socket'], $clients[$clientId]['buffer']);
                        $clients[$clientId]['handshake'] = true;
                        $clients[$clientId]['buffer'] = '';
                    }
                    continue;
                }

                $opcode = ord($chunk[0]) & 0x0f;
                if ($opcode === 0x08) {
                    fclose($stream);
                    unset($clients[$clientId]);
                }
            }
        }
    }

    private function createServer(string $host, int $port)
    {
        $server = @stream_socket_server("tcp://{$host}:{$port}", $errno, $errstr);
        if (! $server) {
            throw new \RuntimeException("Unable to bind {$host}:{$port} - {$errstr} ({$errno})");
        }

        stream_set_blocking($server, false);
        return $server;
    }

    private function finishHandshake($client, string $request): void
    {
        if (! preg_match('/Sec-WebSocket-Key:\s*(.+)\r\n/i', $request, $matches)) {
            fclose($client);
            return;
        }

        $key = trim($matches[1]);
        $accept = base64_encode(sha1($key.'258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true));
        $response = "HTTP/1.1 101 Switching Protocols\r\n".
            "Upgrade: websocket\r\n".
            "Connection: Upgrade\r\n".
            "Sec-WebSocket-Accept: {$accept}\r\n\r\n";
        fwrite($client, $response);
    }

    private function handlePublishPayload(string $payload, array &$clients): void
    {
        $message = json_decode($payload, true);
        if (! is_array($message) || ! isset($message['event'])) {
            return;
        }

        $frame = $this->encodeFrame(json_encode($message, JSON_UNESCAPED_SLASHES));
        if ($frame === '') {
            return;
        }

        foreach ($clients as $clientId => $client) {
            if (! ($client['handshake'] ?? false)) {
                continue;
            }

            $written = @fwrite($client['socket'], $frame);
            if ($written === false) {
                fclose($client['socket']);
                unset($clients[$clientId]);
            }
        }
    }

    private function encodeFrame(string $payload): string
    {
        $length = strlen($payload);
        $head = chr(0x81);

        if ($length <= 125) {
            return $head.chr($length).$payload;
        }

        if ($length <= 65535) {
            return $head.chr(126).pack('n', $length).$payload;
        }

        return $head.chr(127).pack('NN', 0, $length).$payload;
    }
}
