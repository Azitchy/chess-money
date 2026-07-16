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
Route::get('/login', fn () => redirect()->route('admin.login'))->name('login');

Route::middleware(['auth', 'admin.web'])->prefix('admin')->group(function () {
    Route::get('/dashboard', [AdminDashboardController::class, 'index'])->name('admin.dashboard');
    Route::post('/settings/commission', [AdminDashboardController::class, 'updateCommission'])->name('admin.settings.commission');
    Route::get('/users', [AdminDashboardController::class, 'users'])->name('admin.users');
    Route::get('/users/create', [AdminDashboardController::class, 'createUser'])->name('admin.users.create');
    Route::post('/users', [AdminDashboardController::class, 'storeUser'])->name('admin.users.store');
    Route::get('/users/{user}/edit', [AdminDashboardController::class, 'editUser'])->name('admin.users.edit');
    Route::put('/users/{user}', [AdminDashboardController::class, 'updateUser'])->name('admin.users.update');
    Route::delete('/users/{user}', [AdminDashboardController::class, 'deleteUser'])->name('admin.users.delete');
    Route::post('/users/{user}/toggle-status', [AdminDashboardController::class, 'toggleUserStatus'])->name('admin.users.toggle-status');
    Route::get('/users/{user}/wallet', [AdminDashboardController::class, 'walletForm'])->name('admin.users.wallet.form');
    Route::post('/users/{user}/wallet', [AdminDashboardController::class, 'walletAdjust'])->name('admin.users.wallet.adjust');
    Route::get('/funding-requests', [AdminDashboardController::class, 'fundingRequests'])->name('admin.funding-requests');
    Route::get('/funding-requests/summary', [AdminDashboardController::class, 'walletConversationSummary'])->name('admin.funding-requests.summary');
    Route::get('/funding-requests/{conversation}', [AdminDashboardController::class, 'walletConversationThread'])->name('admin.funding-requests.thread');
    Route::post('/funding-requests/{conversation}/reply', [AdminDashboardController::class, 'replyFunding'])->name('admin.funding-requests.reply');
    Route::post('/funding-requests/{conversation}/approve', [AdminDashboardController::class, 'approveFunding'])->name('admin.funding-requests.approve');
    Route::post('/funding-requests/{conversation}/reject', [AdminDashboardController::class, 'rejectFunding'])->name('admin.funding-requests.reject');
    Route::get('/withdraw-requests', [AdminDashboardController::class, 'withdrawRequests'])->name('admin.withdraw-requests');
    Route::get('/withdraw-requests/summary', [AdminDashboardController::class, 'walletConversationSummary'])->name('admin.withdraw-requests.summary');
    Route::get('/withdraw-requests/{conversation}', [AdminDashboardController::class, 'walletConversationThread'])->name('admin.withdraw-requests.thread');
    Route::post('/withdraw-requests/{conversation}/reply', [AdminDashboardController::class, 'replyWithdrawal'])->name('admin.withdraw-requests.reply');
    Route::post('/withdraw-requests/{conversation}/approve', [AdminDashboardController::class, 'approveWithdrawal'])->name('admin.withdraw-requests.approve');
    Route::post('/withdraw-requests/{conversation}/reject', [AdminDashboardController::class, 'rejectWithdrawal'])->name('admin.withdraw-requests.reject');
    Route::get('/matches', [AdminDashboardController::class, 'matches'])->name('admin.matches');
    Route::get('/transactions', [AdminDashboardController::class, 'transactions'])->name('admin.transactions');
});
