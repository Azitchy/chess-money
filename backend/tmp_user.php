<?php
require 'vendor/autoload.php';
$app = require 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
$user = App\Models\User::where('username','test1')->orWhere('email','test1@g.com')->first();
echo $user ? json_encode(['id'=>$user->id,'name'=>$user->name,'username'=>$user->username,'email'=>$user->email,'password'=>$user->password], JSON_UNESCAPED_SLASHES) : 'null';
