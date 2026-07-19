<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
$user = App\Models\User::where('username','demo1')->orWhere('email','demo1@gmail.com')->first();
var_export(password_verify('password', $user->password));
