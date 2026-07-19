<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
foreach (App\Models\User::select('id','name','username','email','is_admin','is_active')->orderBy('id')->get() as $user) {
    echo json_encode($user->toArray(), JSON_UNESCAPED_SLASHES) . PHP_EOL;
}
