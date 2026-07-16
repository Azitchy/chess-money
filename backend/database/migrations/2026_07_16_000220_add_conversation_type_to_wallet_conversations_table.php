<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wallet_conversations', function (Blueprint $table) {
            $table->string('conversation_type')->default('funding')->after('user_id');
            $table->index(
                ['conversation_type', 'status', 'last_message_at'],
                'wc_type_status_last_at_idx'
            );
        });
    }

    public function down(): void
    {
        Schema::table('wallet_conversations', function (Blueprint $table) {
            $table->dropIndex('wc_type_status_last_at_idx');
            $table->dropColumn('conversation_type');
        });
    }
};
