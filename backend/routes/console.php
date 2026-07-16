<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('notifications:ws-server {--host=127.0.0.1} {--ws-port=8081} {--publish-port=8082}', function () {
    app(\App\Services\NotificationWebSocketServer::class)->run(
        (string) $this->option('host'),
        (int) $this->option('ws-port'),
        (int) $this->option('publish-port'),
    );
})->purpose('Run the notification websocket server');
