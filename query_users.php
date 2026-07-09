<?php

$pdo = new PDO('mysql:host=127.0.0.1;port=3306;dbname=chessgame', 'root', '');
$rows = $pdo->query('select email, username, is_admin from users order by is_admin desc, id asc limit 2')->fetchAll(PDO::FETCH_ASSOC);

foreach ($rows as $row) {
    echo $row['email'] . '|' . $row['username'] . '|' . $row['is_admin'] . PHP_EOL;
}
