<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('wallet_conversations', 'conversation_type')) {
            Schema::table('wallet_conversations', function (Blueprint $table) {
                $table->string('conversation_type')->default('funding')->after('user_id');
            });
        }

        if (! $this->hasIndex('wallet_conversations', 'wc_type_status_last_at_idx')) {
            Schema::table('wallet_conversations', function (Blueprint $table) {
                $table->index(
                    ['conversation_type', 'status', 'last_message_at'],
                    'wc_type_status_last_at_idx'
                );
            });
        }
    }

    public function down(): void
    {
        Schema::table('wallet_conversations', function (Blueprint $table) {
            if ($this->hasIndex('wallet_conversations', 'wc_type_status_last_at_idx')) {
                $table->dropIndex('wc_type_status_last_at_idx');
            }
            if (Schema::hasColumn('wallet_conversations', 'conversation_type')) {
                $table->dropColumn('conversation_type');
            }
        });
    }

    private function hasIndex(string $table, string $indexName): bool
    {
        $database = DB::getDatabaseName();

        return DB::table('information_schema.statistics')
            ->where('table_schema', $database)
            ->where('table_name', $table)
            ->where('index_name', $indexName)
            ->exists();
    }
};
