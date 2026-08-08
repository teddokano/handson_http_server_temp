/*
 * Copyright (c) 2023, Emna Rekik
 * Copyright (c) 2024, Nordic Semiconductor
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * --- ハンズオン用改変 ---
 * Zephyr公式サンプル samples/net/sockets/http_server/src/main.c をベースに、
 * /temperature エンドポイントを追加。samples/sensor/thermometer と同じ
 * DT_ALIAS(ambient_temp0) を使って温度センサーを読み、HTMLとして返す。
 */

#include <stdio.h>
#include <inttypes.h>
#include <zephyr/kernel.h>
#include <zephyr/net/tls_credentials.h>
#include <zephyr/net/http/server.h>
#include <zephyr/net/http/service.h>
#include <zephyr/net/net_ip.h>
#include <zephyr/net/socket.h>
#include "zephyr/device.h"
#include "zephyr/sys/util.h"
#include <zephyr/drivers/led.h>
#include <zephyr/drivers/sensor.h>   /* 追加: 温度センサー読み取り用 */
#include <zephyr/data/json.h>
#include <zephyr/sys/util_macro.h>
#include <zephyr/net/net_config.h>
#if CONFIG_USB_DEVICE_STACK_NEXT
#include <sample_usbd.h>
#endif

#include "ws.h"

#include <zephyr/logging/log.h>
LOG_MODULE_REGISTER(net_http_server_sample, LOG_LEVEL_DBG);

struct led_command {
	int led_num;
	bool led_state;
};

static const struct json_obj_descr led_command_descr[] = {
	JSON_OBJ_DESCR_PRIM(struct led_command, led_num, JSON_TOK_NUMBER),
	JSON_OBJ_DESCR_PRIM(struct led_command, led_state, JSON_TOK_TRUE),
};

static const struct device *leds_dev = DEVICE_DT_GET_ANY(gpio_leds);

/* 追加: samples/sensor/thermometer と同じエイリアスで温度センサーを取得 */
static const struct device *const temp_dev = DEVICE_DT_GET(DT_ALIAS(ambient_temp0));

static uint8_t index_html_gz[] = {
#include "index.html.gz.inc"
};

static uint8_t main_js_gz[] = {
#include "main.js.gz.inc"
};

static struct http_resource_detail_static index_html_gz_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_STATIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
			.content_encoding = "gzip",
			.content_type = "text/html",
		},
	.static_data = index_html_gz,
	.static_data_len = sizeof(index_html_gz),
};

static struct http_resource_detail_static main_js_gz_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_STATIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
			.content_encoding = "gzip",
			.content_type = "text/javascript",
		},
	.static_data = main_js_gz,
	.static_data_len = sizeof(main_js_gz),
};

static int echo_handler(struct http_client_ctx *client, enum http_transaction_status status,
			 const struct http_request_ctx *request_ctx,
			 struct http_response_ctx *response_ctx, void *user_data)
{
#define MAX_TEMP_PRINT_LEN 32
	static char print_str[MAX_TEMP_PRINT_LEN];
	enum http_method method = client->method;
	static size_t processed;

	if (status == HTTP_SERVER_TRANSACTION_ABORTED ||
	    status == HTTP_SERVER_TRANSACTION_COMPLETE) {
		if (status == HTTP_SERVER_TRANSACTION_ABORTED) {
			LOG_DBG("Transaction aborted after %zd bytes.", processed);
		}
		processed = 0;
		return 0;
	}

	__ASSERT_NO_MSG(request_ctx->data != NULL);

	processed += request_ctx->data_len;

	snprintf(print_str, sizeof(print_str), "%s received (%zd bytes)", http_method_str(method),
		 request_ctx->data_len);
	LOG_HEXDUMP_DBG(request_ctx->data, request_ctx->data_len, print_str);

	if (status == HTTP_SERVER_REQUEST_DATA_FINAL) {
		LOG_DBG("All data received (%zd bytes).", processed);
		processed = 0;
	}

	/* Echo data back to client */
	response_ctx->body = request_ctx->data;
	response_ctx->body_len = request_ctx->data_len;
	response_ctx->final_chunk = (status == HTTP_SERVER_REQUEST_DATA_FINAL);

	return 0;
}

static struct http_resource_detail_dynamic echo_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_DYNAMIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET) | BIT(HTTP_POST),
		},
	.cb = echo_handler,
	.user_data = NULL,
};

static int uptime_handler(struct http_client_ctx *client, enum http_transaction_status status,
			   const struct http_request_ctx *request_ctx,
			   struct http_response_ctx *response_ctx, void *user_data)
{
	int ret;
	static uint8_t uptime_buf[sizeof(STRINGIFY(INT64_MAX))];

	LOG_DBG("Uptime handler status %d", status);

	/* A payload is not expected with the GET request. Ignore any data and wait until
	 * final callback before sending response
	 */
	if (status == HTTP_SERVER_REQUEST_DATA_FINAL) {
		ret = snprintf(uptime_buf, sizeof(uptime_buf), "%" PRId64, k_uptime_get());
		if (ret < 0) {
			LOG_ERR("Failed to snprintf uptime, err %d", ret);
			return ret;
		}

		response_ctx->body = uptime_buf;
		response_ctx->body_len = ret;
		response_ctx->final_chunk = true;
	}

	return 0;
}

static struct http_resource_detail_dynamic uptime_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_DYNAMIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
		},
	.cb = uptime_handler,
	.user_data = NULL,
};

/* ----------------- 追加: /temperature エンドポイント ----------------- */

/* センサー読み取りを /temperature (HTML) と /temperature.json (ポーリング用) で共有 */
static int read_temperature_c(double *temp_c)
{
	struct sensor_value val;

	if (!device_is_ready(temp_dev)) {
		LOG_ERR("Temperature sensor device %s is not ready", temp_dev->name);
		return -ENODEV;
	}
	if (sensor_sample_fetch_chan(temp_dev, SENSOR_CHAN_AMBIENT_TEMP) < 0) {
		LOG_ERR("Failed to fetch temperature sample");
		return -EIO;
	}
	if (sensor_channel_get(temp_dev, SENSOR_CHAN_AMBIENT_TEMP, &val) < 0) {
		LOG_ERR("Failed to get temperature channel");
		return -EIO;
	}

	*temp_c = sensor_value_to_double(&val);
	return 0;
}

/* index.html と見た目(フォント/余白)を揃えつつ、uptime表示と同じ
 * setInterval(1000ms)ポーリングで /temperature.json から1秒ごとに更新する。 */
#define TEMPERATURE_PAGE_FMT \
	"<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">" \
	"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" \
	"<title>Zephyr HTTP Server</title><style>" \
	"body{margin:0;padding:16px;font-family:sans-serif;line-height:1.4;}" \
	"h1,h4{margin:0 0 8px;}p{margin:0 0 12px;}" \
	"</style></head><body>" \
	"<h1>Hello FRDM-MCXN947 temp sensor: P3T1755</h1>" \
	"<h4 id=\"temp\">%s</h4>" \
	"<p><a href=\"/\">&larr; Back</a></p>" \
	"<script>" \
	"async function fetchTemp(){" \
	"try{" \
	"const r=await fetch(\"/temperature.json\");" \
	"if(!r.ok)throw new Error(r.status);" \
	"const t=await r.json();" \
	"document.getElementById(\"temp\").innerHTML=" \
	"(t===null?\"Sensor error\":\"Temperature: \"+t.toFixed(1)+\"&deg;C\");" \
	"}catch(e){console.error(e.message);}" \
	"}" \
	"setInterval(fetchTemp,1000);" \
	"</script></body></html>"

static int temperature_handler(struct http_client_ctx *client, enum http_transaction_status status,
				const struct http_request_ctx *request_ctx,
				struct http_response_ctx *response_ctx, void *user_data)
{
	int ret;
	double temp_c;
	char msg_buf[32];
	static char body_buf[sizeof(TEMPERATURE_PAGE_FMT) + sizeof(msg_buf)];

	LOG_DBG("Temperature handler status %d", status);

	/* GETのみ想定。ペイロードは無いので最終コールバックまで待って応答する */
	if (status == HTTP_SERVER_REQUEST_DATA_FINAL) {
		if (read_temperature_c(&temp_c) < 0) {
			snprintf(msg_buf, sizeof(msg_buf), "Sensor error");
		} else {
			snprintf(msg_buf, sizeof(msg_buf), "Temperature: %.1f&deg;C", temp_c);
		}

		ret = snprintf(body_buf, sizeof(body_buf), TEMPERATURE_PAGE_FMT, msg_buf);
		if (ret < 0) {
			LOG_ERR("Failed to snprintf response body, err %d", ret);
			return ret;
		}

		response_ctx->body = body_buf;
		response_ctx->body_len = ret;
		response_ctx->final_chunk = true;
	}

	return 0;
}

static struct http_resource_detail_dynamic temperature_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_DYNAMIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
		},
	.cb = temperature_handler,
	.user_data = NULL,
};

/* /temperature.json: 1秒ごとのポーリング用。生の数値(またはnull)のみ返す */
static int temperature_json_handler(struct http_client_ctx *client, enum http_transaction_status status,
				     const struct http_request_ctx *request_ctx,
				     struct http_response_ctx *response_ctx, void *user_data)
{
	int ret;
	double temp_c;
	static char body_buf[16];

	if (status == HTTP_SERVER_REQUEST_DATA_FINAL) {
		if (read_temperature_c(&temp_c) < 0) {
			ret = snprintf(body_buf, sizeof(body_buf), "null");
		} else {
			ret = snprintf(body_buf, sizeof(body_buf), "%.1f", temp_c);
		}
		if (ret < 0) {
			LOG_ERR("Failed to snprintf response body, err %d", ret);
			return ret;
		}

		response_ctx->body = body_buf;
		response_ctx->body_len = ret;
		response_ctx->final_chunk = true;
	}

	return 0;
}

static struct http_resource_detail_dynamic temperature_json_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_DYNAMIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
		},
	.cb = temperature_json_handler,
	.user_data = NULL,
};

/* --------------------------------------------------------------------- */

static void parse_led_post(uint8_t *buf, size_t len)
{
	int ret;
	struct led_command cmd;
	const int expected_return_code = BIT_MASK(ARRAY_SIZE(led_command_descr));

	ret = json_obj_parse(buf, len, led_command_descr, ARRAY_SIZE(led_command_descr), &cmd);
	if (ret != expected_return_code) {
		LOG_WRN("Failed to fully parse JSON payload, ret=%d", ret);
		return;
	}

	LOG_INF("POST request setting LED %d to state %d", cmd.led_num, cmd.led_state);

	if (leds_dev != NULL) {
		if (cmd.led_state) {
			led_on(leds_dev, cmd.led_num);
		} else {
			led_off(leds_dev, cmd.led_num);
		}
	}
}

static int led_handler(struct http_client_ctx *client, enum http_transaction_status status,
			const struct http_request_ctx *request_ctx,
			struct http_response_ctx *response_ctx, void *user_data)
{
	static uint8_t post_payload_buf[32];
	static size_t cursor;

	LOG_DBG("LED handler status %d, size %zu", status, request_ctx->data_len);

	if (status == HTTP_SERVER_TRANSACTION_ABORTED ||
	    status == HTTP_SERVER_TRANSACTION_COMPLETE) {
		cursor = 0;
		return 0;
	}

	if (request_ctx->data_len + cursor > sizeof(post_payload_buf)) {
		cursor = 0;
		return -ENOMEM;
	}

	memcpy(post_payload_buf + cursor, request_ctx->data, request_ctx->data_len);
	cursor += request_ctx->data_len;

	if (status == HTTP_SERVER_REQUEST_DATA_FINAL) {
		parse_led_post(post_payload_buf, cursor);
		cursor = 0;
	}

	return 0;
}

static struct http_resource_detail_dynamic led_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_DYNAMIC,
			.bitmask_of_supported_http_methods = BIT(HTTP_POST),
		},
	.cb = led_handler,
	.user_data = NULL,
};

#if defined(CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE)
static uint8_t ws_echo_buffer[1024];

struct http_resource_detail_websocket ws_echo_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_WEBSOCKET,
			/* We need HTTP/1.1 Get method for upgrading */
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
		},
	.cb = ws_echo_setup,
	.data_buffer = ws_echo_buffer,
	.data_buffer_len = sizeof(ws_echo_buffer),
	.user_data = NULL, /* Fill this for any user specific data */
};

static uint8_t ws_netstats_buffer[128];

struct http_resource_detail_websocket ws_netstats_resource_detail = {
	.common = {
			.type = HTTP_RESOURCE_TYPE_WEBSOCKET,
			.bitmask_of_supported_http_methods = BIT(HTTP_GET),
		},
	.cb = ws_netstats_setup,
	.data_buffer = ws_netstats_buffer,
	.data_buffer_len = sizeof(ws_netstats_buffer),
	.user_data = NULL,
};
#endif /* CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE */

#if defined(CONFIG_NET_SAMPLE_HTTP_SERVICE)
static uint16_t test_http_service_port = CONFIG_NET_SAMPLE_HTTP_SERVER_SERVICE_PORT;
HTTP_SERVICE_DEFINE(test_http_service, NULL, &test_http_service_port,
		     CONFIG_HTTP_SERVER_MAX_CLIENTS, 10, NULL, NULL, NULL);

HTTP_RESOURCE_DEFINE(index_html_gz_resource, test_http_service, "/",
		      &index_html_gz_resource_detail);

HTTP_RESOURCE_DEFINE(main_js_gz_resource, test_http_service, "/main.js",
		      &main_js_gz_resource_detail);

HTTP_RESOURCE_DEFINE(echo_resource, test_http_service, "/dynamic", &echo_resource_detail);

HTTP_RESOURCE_DEFINE(uptime_resource, test_http_service, "/uptime", &uptime_resource_detail);

HTTP_RESOURCE_DEFINE(led_resource, test_http_service, "/led", &led_resource_detail);

/* 追加: /temperature エンドポイントを登録 */
HTTP_RESOURCE_DEFINE(temperature_resource, test_http_service, "/temperature",
		      &temperature_resource_detail);

HTTP_RESOURCE_DEFINE(temperature_json_resource, test_http_service, "/temperature.json",
		      &temperature_json_resource_detail);

#if defined(CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE)
HTTP_RESOURCE_DEFINE(ws_echo_resource, test_http_service, "/ws_echo", &ws_echo_resource_detail);
HTTP_RESOURCE_DEFINE(ws_netstats_resource, test_http_service, "/", &ws_netstats_resource_detail);
#endif /* CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE */
#endif /* CONFIG_NET_SAMPLE_HTTP_SERVICE */

/*
 * 注: 今回のハンズオンはTLS無しのプレーンHTTP+固定IP運用のため、
 * CONFIG_NET_SAMPLE_HTTPS_SERVICE 側の定義は元サンプルのままにしてあります
 * (Kconfigで無効化されていれば以下は単にビルドされません)。
 */
#if defined(CONFIG_NET_SAMPLE_HTTPS_SERVICE)
#include "certificate.h"

static const sec_tag_t sec_tag_list_verify_none[] = {
	HTTP_SERVER_CERTIFICATE_TAG,
#if defined(CONFIG_MBEDTLS_KEY_EXCHANGE_PSK_ENABLED)
	PSK_TAG,
#endif
};

static uint16_t test_https_service_port = CONFIG_NET_SAMPLE_HTTPS_SERVER_SERVICE_PORT;
HTTPS_SERVICE_DEFINE(test_https_service, NULL, &test_https_service_port,
		      CONFIG_HTTP_SERVER_MAX_CLIENTS, 10, NULL, NULL, NULL, sec_tag_list_verify_none,
		      sizeof(sec_tag_list_verify_none));

HTTP_RESOURCE_DEFINE(index_html_gz_resource_https, test_https_service, "/",
		      &index_html_gz_resource_detail);

HTTP_RESOURCE_DEFINE(main_js_gz_resource_https, test_https_service, "/main.js",
		      &main_js_gz_resource_detail);

HTTP_RESOURCE_DEFINE(echo_resource_https, test_https_service, "/dynamic", &echo_resource_detail);

HTTP_RESOURCE_DEFINE(uptime_resource_https, test_https_service, "/uptime", &uptime_resource_detail);

HTTP_RESOURCE_DEFINE(led_resource_https, test_https_service, "/led", &led_resource_detail);

#if defined(CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE)
HTTP_RESOURCE_DEFINE(ws_echo_resource_https, test_https_service, "/ws_echo",
		      &ws_echo_resource_detail);
HTTP_RESOURCE_DEFINE(ws_netstats_resource_https, test_https_service, "/",
		      &ws_netstats_resource_detail);
#endif /* CONFIG_NET_SAMPLE_WEBSOCKET_SERVICE */
#endif /* CONFIG_NET_SAMPLE_HTTPS_SERVICE */

static void setup_tls(void)
{
#if defined(CONFIG_NET_SAMPLE_HTTPS_SERVICE)
#if defined(CONFIG_NET_SOCKETS_SOCKOPT_TLS)
	int err;

	err = tls_credential_add(HTTP_SERVER_CERTIFICATE_TAG,
				  TLS_CREDENTIAL_PUBLIC_CERTIFICATE,
				  server_certificate,
				  sizeof(server_certificate));
	if (err < 0) {
		LOG_ERR("Failed to register public certificate: %d", err);
	}

	err = tls_credential_add(HTTP_SERVER_CERTIFICATE_TAG,
				  TLS_CREDENTIAL_PRIVATE_KEY,
				  private_key, sizeof(private_key));
	if (err < 0) {
		LOG_ERR("Failed to register private key: %d", err);
	}

#if defined(CONFIG_MBEDTLS_KEY_EXCHANGE_PSK_ENABLED)
	err = tls_credential_add(PSK_TAG,
				  TLS_CREDENTIAL_PSK,
				  psk,
				  sizeof(psk));
	if (err < 0) {
		LOG_ERR("Failed to register PSK: %d", err);
	}

	err = tls_credential_add(PSK_TAG,
				  TLS_CREDENTIAL_PSK_ID,
				  psk_id,
				  sizeof(psk_id) - 1);
	if (err < 0) {
		LOG_ERR("Failed to register PSK ID: %d", err);
	}
#endif /* defined(CONFIG_MBEDTLS_KEY_EXCHANGE_PSK_ENABLED) */
#endif /* defined(CONFIG_NET_SOCKETS_SOCKOPT_TLS) */
#endif /* defined(CONFIG_NET_SAMPLE_HTTPS_SERVICE) */
}

static int init_usb(void)
{
#if defined(CONFIG_USB_DEVICE_STACK_NEXT)
	struct usbd_context *sample_usbd;
	int err;

	sample_usbd = sample_usbd_init_device(NULL);
	if (sample_usbd == NULL) {
		return -ENODEV;
	}

	err = usbd_enable(sample_usbd);
	if (err) {
		return err;
	}

	(void)net_config_init_app(NULL, "Initializing network");
#endif /* CONFIG_USB_DEVICE_STACK_NEXT */

	return 0;
}

int main(void)
{
	init_usb();
	setup_tls();

	/* 追加: 起動時に温度センサーの準備状態をログに出す */
	if (!device_is_ready(temp_dev)) {
		LOG_ERR("Temperature sensor device is not ready");
	} else {
		LOG_INF("Temperature sensor device %s is ready", temp_dev->name);
	}

	http_server_start();

	return 0;
}
