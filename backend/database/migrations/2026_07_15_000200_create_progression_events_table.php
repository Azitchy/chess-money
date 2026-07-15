<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('progression_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->enum('activity_type', ['puzzle', 'bot']);
            $table->string('activity_key');
            $table->json('details')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'activity_type', 'activity_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('progression_events');
    }
};
