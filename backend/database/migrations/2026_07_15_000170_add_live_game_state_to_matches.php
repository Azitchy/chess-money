<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->json('moves')->nullable()->after('status');
            $table->json('result_claims')->nullable()->after('moves');
            $table->foreignId('current_turn_user_id')
                ->nullable()
                ->after('result_claims')
                ->constrained('users')
                ->nullOnDelete();
            $table->timestamp('rejected_at')->nullable()->after('ended_at');
        });
    }

    public function down(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->dropConstrainedForeignId('current_turn_user_id');
            $table->dropColumn(['moves', 'result_claims', 'rejected_at']);
        });
    }
};
