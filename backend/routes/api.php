<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\MatchController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\PresenceController;
use App\Http\Controllers\Api\ProgressController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('token.auth')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::post('/profile', [ProfileController::class, 'update']);
    Route::get('/presence', [PresenceController::class, 'show']);
    Route::post('/presence', [PresenceController::class, 'update']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/users', [UserController::class, 'index']);

    Route::get('/wallet', [WalletController::class, 'show']);
    Route::get('/wallet/transactions', [WalletController::class, 'transactions']);
    Route::post('/wallet/request-funds', [WalletController::class, 'requestFunds']);

    Route::post('/progress/puzzle-completed', [ProgressController::class, 'puzzleCompleted']);
    Route::post('/progress/bot-won', [ProgressController::class, 'botWon']);

    Route::post('/matches', [MatchController::class, 'create']);
    Route::get('/matches/history', [MatchController::class, 'history']);
    Route::get('/matches/challenges', [MatchController::class, 'challenges']);
    Route::get('/matches/active', [MatchController::class, 'active']);
    Route::post('/matches/{match}/accept', [MatchController::class, 'accept']);
    Route::post('/matches/{match}/reject', [MatchController::class, 'reject']);
    Route::get('/matches/{match}/state', [MatchController::class, 'state']);
    Route::post('/matches/{match}/move', [MatchController::class, 'move']);
    Route::post('/matches/{match}/end', [MatchController::class, 'end']);

    Route::middleware('admin.only')->group(function () {
        Route::get('/admin/funding-requests', [AdminController::class, 'fundingRequests']);
        Route::post('/admin/funding-requests/{fundingRequest}/approve', [AdminController::class, 'approveFunding']);
    });
});
