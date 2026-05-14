<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AdminDashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('admin.login');
});

Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login'])->name('admin.login.submit');
Route::post('/admin/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');

Route::middleware(['auth', 'admin.web'])->prefix('admin')->group(function () {
    Route::get('/dashboard', [AdminDashboardController::class, 'index'])->name('admin.dashboard');
    Route::get('/users', [AdminDashboardController::class, 'users'])->name('admin.users');
    Route::post('/users/{user}/toggle-status', [AdminDashboardController::class, 'toggleUserStatus'])->name('admin.users.toggle-status');
    Route::get('/users/{user}/wallet', [AdminDashboardController::class, 'walletForm'])->name('admin.users.wallet.form');
    Route::post('/users/{user}/wallet', [AdminDashboardController::class, 'walletAdjust'])->name('admin.users.wallet.adjust');
    Route::get('/funding-requests', [AdminDashboardController::class, 'fundingRequests'])->name('admin.funding-requests');
    Route::post('/funding-requests/{fundingRequest}/approve', [AdminDashboardController::class, 'approveFunding'])->name('admin.funding-requests.approve');
    Route::post('/funding-requests/{fundingRequest}/reject', [AdminDashboardController::class, 'rejectFunding'])->name('admin.funding-requests.reject');
    Route::get('/matches', [AdminDashboardController::class, 'matches'])->name('admin.matches');
    Route::get('/transactions', [AdminDashboardController::class, 'transactions'])->name('admin.transactions');
});
