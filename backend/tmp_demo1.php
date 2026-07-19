<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
$user = App\Models\User::where('username','demo1')->orWhere('email','demo1@gmail.com')->first();
echo $user ? json_encode(['id'=>$user->id,'username'=>$user->username,'email'=>$user->email,'password'=>$user->password], JSON_UNESCAPED_SLASHES) : 'null';
