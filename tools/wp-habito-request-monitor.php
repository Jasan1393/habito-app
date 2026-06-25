<?php
/**
 * Plugin Name: Habito Request Monitor
 * Description: Logs slow WordPress requests and cron runs for VPS freeze diagnosis.
 * Version: 0.1.0
 * Author: Habito
 *
 * Install as:
 *   wp-content/mu-plugins/wp-habito-request-monitor.php
 *
 * Optional wp-config.php constants:
 *   define( 'HABITO_MONITOR_ENABLED', true );
 *   define( 'HABITO_MONITOR_SLOW_SECONDS', 3.0 );
 *   define( 'HABITO_MONITOR_CRON_SECONDS', 1.0 );
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( defined( 'HABITO_MONITOR_ENABLED' ) && ! HABITO_MONITOR_ENABLED ) {
	return;
}

if ( ! defined( 'HABITO_MONITOR_START' ) ) {
	define( 'HABITO_MONITOR_START', microtime( true ) );
}

if ( ! defined( 'HABITO_MONITOR_START_MEMORY' ) ) {
	define( 'HABITO_MONITOR_START_MEMORY', memory_get_usage( true ) );
}

add_action(
	'shutdown',
	static function () {
		global $wpdb;

		$duration      = microtime( true ) - HABITO_MONITOR_START;
		$slow_seconds  = defined( 'HABITO_MONITOR_SLOW_SECONDS' ) ? (float) HABITO_MONITOR_SLOW_SECONDS : 3.0;
		$cron_seconds  = defined( 'HABITO_MONITOR_CRON_SECONDS' ) ? (float) HABITO_MONITOR_CRON_SECONDS : 1.0;
		$is_cron       = defined( 'DOING_CRON' ) && DOING_CRON;
		$is_rest       = defined( 'REST_REQUEST' ) && REST_REQUEST;
		$should_record = $duration >= $slow_seconds || ( $is_cron && $duration >= $cron_seconds );

		if ( ! $should_record ) {
			return;
		}

		$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
		$path        = (string) wp_parse_url( $request_uri, PHP_URL_PATH );
		$query       = (string) wp_parse_url( $request_uri, PHP_URL_QUERY );
		$query_keys  = array();

		if ( '' !== $query ) {
			parse_str( $query, $query_args );
			if ( is_array( $query_args ) ) {
				$query_keys = array_keys( $query_args );
				sort( $query_keys );
			}
		}

		$record = array(
			'time_utc'          => gmdate( 'c' ),
			'duration_seconds'  => round( $duration, 4 ),
			'memory_start_mb'   => round( HABITO_MONITOR_START_MEMORY / 1048576, 2 ),
			'memory_peak_mb'    => round( memory_get_peak_usage( true ) / 1048576, 2 ),
			'db_queries'        => isset( $wpdb->num_queries ) ? (int) $wpdb->num_queries : null,
			'method'            => isset( $_SERVER['REQUEST_METHOD'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REQUEST_METHOD'] ) ) : '',
			'path'              => $path,
			'query_keys'        => $query_keys,
			'rest_route'        => isset( $_GET['rest_route'] ) ? sanitize_text_field( wp_unslash( $_GET['rest_route'] ) ) : '',
			'admin_ajax_action' => isset( $_REQUEST['action'] ) ? sanitize_key( wp_unslash( $_REQUEST['action'] ) ) : '',
			'is_rest'           => $is_rest,
			'is_cron'           => $is_cron,
			'is_admin'          => is_admin(),
			'user_id'           => get_current_user_id(),
			'php_sapi'          => PHP_SAPI,
			'pid'               => getmypid(),
			'status_code'       => function_exists( 'http_response_code' ) ? http_response_code() : null,
		);

		$last_error = error_get_last();
		if ( is_array( $last_error ) ) {
			$record['last_error'] = array(
				'type'    => isset( $last_error['type'] ) ? (int) $last_error['type'] : null,
				'message' => isset( $last_error['message'] ) ? (string) $last_error['message'] : '',
				'file'    => isset( $last_error['file'] ) ? basename( (string) $last_error['file'] ) : '',
				'line'    => isset( $last_error['line'] ) ? (int) $last_error['line'] : null,
			);
		}

		$upload_dir = wp_upload_dir( null, false );
		$base_dir   = isset( $upload_dir['basedir'] ) ? $upload_dir['basedir'] : WP_CONTENT_DIR;
		$log_dir    = trailingslashit( $base_dir ) . 'habito-monitor';

		if ( ! wp_mkdir_p( $log_dir ) ) {
			error_log( '[Habito Request Monitor] ' . wp_json_encode( $record ) );
			return;
		}

		$log_file = trailingslashit( $log_dir ) . 'slow-requests-' . gmdate( 'Y-m-d' ) . '.log';
		$line     = wp_json_encode( $record, JSON_UNESCAPED_SLASHES ) . PHP_EOL;

		file_put_contents( $log_file, $line, FILE_APPEND | LOCK_EX );
	},
	PHP_INT_MAX
);
