<?php
/**
 * ตัวอย่างค่าตั้งเท่านั้น — ห้ามใส่รหัสผ่านจริงในไฟล์นี้
 * wp-config.php ตัวจริงอยู่บนเซิร์ฟเวอร์ (สิทธิ์ 640) และถูกกันไว้ใน .gitignore
 */

define( 'DB_NAME',     'YOUR_DB_NAME' );
define( 'DB_USER',     'YOUR_DB_USER' );
define( 'DB_PASSWORD', 'YOUR_DB_PASSWORD' );
define( 'DB_HOST',     'localhost' );
define( 'DB_CHARSET',  'utf8mb4' );
define( 'DB_COLLATE',  '' );

/* สร้างค่าใหม่ได้ที่ https://api.wordpress.org/secret-key/1.1/salt/ */
define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

$table_prefix = 'wp_';

/* Security hardening */
define( 'DISALLOW_FILE_EDIT', true );
define( 'FORCE_SSL_ADMIN', true );
define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
