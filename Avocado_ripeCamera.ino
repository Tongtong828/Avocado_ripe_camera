#include <Avocado_ripeCamera3_inferencing.h>

#include "edge-impulse-sdk/dsp/image/image.hpp"
#include "camera.h"
#include "gc2145.h"
#include <ea_malloc.h>

#define BAUD_RATE 115200
#define INFERENCE_THRESHOLD 0.70f

// Use a smaller camera resolution to fit memory
#define EI_CAMERA_RAW_FRAME_BUFFER_COLS 160
#define EI_CAMERA_RAW_FRAME_BUFFER_ROWS 120

GC2145 galaxyCore;
Camera cam(galaxyCore);
FrameBuffer fb;

static bool debug_nn = false;
static bool camera_is_initialized = false;

static uint8_t *camera_frame_mem = nullptr;
static uint8_t *camera_frame_buffer = nullptr;

static uint8_t *camera_rgb888_mem = nullptr;
static uint8_t *camera_rgb888 = nullptr;

static uint8_t *ei_camera_capture_out_mem = nullptr;
static uint8_t *ei_camera_capture_out = nullptr;

void run_one_inference(void);
bool ei_camera_init(void);
bool ei_camera_capture(uint32_t img_width, uint32_t img_height);
bool RGB565ToRGB888(uint8_t *src_buf, uint8_t *dst_buf, uint32_t src_len);
static int ei_camera_get_data(size_t offset, size_t length, float *out_ptr);
int get_best_class_index(const ei_impulse_result_t &result, float *best_value);
void print_scores(const ei_impulse_result_t &result);

void setup() {
    Serial.begin(BAUD_RATE);
    delay(2000);

    malloc_addblock((void*)0x30000000, 288 * 1024);

    Serial.println();
    Serial.println("========================================");
    Serial.println("Nicla Vision - Avocado Ripeness Inference");
    Serial.println("Send 'c' in Serial Monitor to capture");
    Serial.println("Baud rate: 115200");
    Serial.println("Camera resolution: 160x120");
    Serial.println("========================================");

    if (!ei_camera_init()) {
        Serial.println("ERR: Camera initialization failed");
        while (1) {
            delay(1000);
        }
    }

    Serial.println("Camera initialized");
    Serial.println("Waiting for serial trigger...");
}

void loop() {
    if (Serial.available()) {
        char cmd = Serial.read();

        while (Serial.available()) {
            Serial.read();
        }

        if (cmd == 'c' || cmd == 'C') {
            run_one_inference();
            Serial.println();
            Serial.println("Waiting for next serial trigger...");
        }
    }
}

void run_one_inference(void) {
    Serial.println("Taking photo...");

    if (!ei_camera_capture((size_t)EI_CLASSIFIER_INPUT_WIDTH,
                           (size_t)EI_CLASSIFIER_INPUT_HEIGHT)) {
        Serial.println("ERR: Failed to capture image");
        return;
    }

    signal_t signal;
    signal.total_length = EI_CLASSIFIER_INPUT_WIDTH * EI_CLASSIFIER_INPUT_HEIGHT;
    signal.get_data = &ei_camera_get_data;

    ei_impulse_result_t result = { 0 };

    EI_IMPULSE_ERROR err = run_classifier(&signal, &result, debug_nn);
    if (err != EI_IMPULSE_OK) {
        Serial.print("ERR: Failed to run classifier (");
        Serial.print((int)err);
        Serial.println(")");
        return;
    }

    Serial.print("Predictions (DSP: ");
    Serial.print(result.timing.dsp);
    Serial.print(" ms, Classification: ");
    Serial.print(result.timing.classification);
    Serial.print(" ms");
#if EI_CLASSIFIER_HAS_ANOMALY == 1
    Serial.print(", Anomaly: ");
    Serial.print(result.timing.anomaly);
    Serial.print(" ms");
#endif
    Serial.println(")");

    print_scores(result);

    float best_value = 0.0f;
    int best_idx = get_best_class_index(result, &best_value);

    if (best_idx < 0 || best_value < INFERENCE_THRESHOLD) {
        Serial.print("Final decision: uncertain (best score = ");
        Serial.print(best_value, 4);
        Serial.println(")");
        return;
    }

    Serial.print("Final decision: ");
    Serial.print(result.classification[best_idx].label);
    Serial.print(" (");
    Serial.print(best_value, 4);
    Serial.println(")");
}

void print_scores(const ei_impulse_result_t &result) {
    Serial.println("Class scores:");
    for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        Serial.print("  ");
        Serial.print(result.classification[ix].label);
        Serial.print(": ");
        Serial.println(result.classification[ix].value, 4);
    }

#if EI_CLASSIFIER_HAS_ANOMALY == 1
    Serial.print("  anomaly: ");
    Serial.println(result.anomaly, 4);
#endif
}

int get_best_class_index(const ei_impulse_result_t &result, float *best_value) {
    int best_idx = -1;
    *best_value = 0.0f;

    for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        if (result.classification[ix].value > *best_value) {
            *best_value = result.classification[ix].value;
            best_idx = (int)ix;
        }
    }

    return best_idx;
}

bool ei_camera_init(void) {
    if (camera_is_initialized) {
        return true;
    }

    if (!cam.begin(CAMERA_R160x120, CAMERA_RGB565, -1)) {
        Serial.println("ERR: Failed to initialise camera");
        return false;
    }

    camera_frame_mem = (uint8_t *)ea_malloc(cam.frameSize() + 32);
    if (!camera_frame_mem) {
        Serial.println("ERR: Failed to allocate camera_frame_mem");
        return false;
    }
    camera_frame_buffer = (uint8_t *)(((uintptr_t)camera_frame_mem + 31) & ~(uintptr_t)31);

    camera_rgb888_mem = (uint8_t *)ea_malloc(EI_CAMERA_RAW_FRAME_BUFFER_COLS *
                                             EI_CAMERA_RAW_FRAME_BUFFER_ROWS * 3 + 32);
    if (!camera_rgb888_mem) {
        Serial.println("ERR: Failed to allocate camera_rgb888");
        return false;
    }
    camera_rgb888 = (uint8_t *)(((uintptr_t)camera_rgb888_mem + 31) & ~(uintptr_t)31);

    ei_camera_capture_out_mem = (uint8_t *)ea_malloc(EI_CLASSIFIER_INPUT_WIDTH *
                                                     EI_CLASSIFIER_INPUT_HEIGHT * 3 + 32);
    if (!ei_camera_capture_out_mem) {
        Serial.println("ERR: Failed to allocate ei_camera_capture_out");
        return false;
    }
    ei_camera_capture_out = (uint8_t *)(((uintptr_t)ei_camera_capture_out_mem + 31) & ~(uintptr_t)31);

    fb.setBuffer(camera_frame_buffer);

    camera_is_initialized = true;
    return true;
}

bool ei_camera_capture(uint32_t img_width, uint32_t img_height) {
    if (!camera_is_initialized) {
        Serial.println("ERR: Camera not initialized");
        return false;
    }

    int snapshot_response = cam.grabFrame(fb, 3000);
    if (snapshot_response != 0) {
        Serial.print("ERR: Failed to get snapshot (");
        Serial.print(snapshot_response);
        Serial.println(")");
        return false;
    }

    bool converted = RGB565ToRGB888(camera_frame_buffer, camera_rgb888, cam.frameSize());
    if (!converted) {
        Serial.println("ERR: RGB565 to RGB888 conversion failed");
        return false;
    }

    ei::image::processing::crop_and_interpolate_rgb888(
        camera_rgb888,
        EI_CAMERA_RAW_FRAME_BUFFER_COLS,
        EI_CAMERA_RAW_FRAME_BUFFER_ROWS,
        ei_camera_capture_out,
        img_width,
        img_height
    );

    return true;
}

bool RGB565ToRGB888(uint8_t *src_buf, uint8_t *dst_buf, uint32_t src_len) {
    uint8_t hb, lb;
    uint32_t pix_count = src_len / 2;

    for (uint32_t i = 0; i < pix_count; i++) {
        hb = *src_buf++;
        lb = *src_buf++;

        *dst_buf++ = hb & 0xF8;
        *dst_buf++ = (hb & 0x07) << 5 | (lb & 0xE0) >> 3;
        *dst_buf++ = (lb & 0x1F) << 3;
    }

    return true;
}

static int ei_camera_get_data(size_t offset, size_t length, float *out_ptr) {
    size_t pixel_ix = offset * 3;
    size_t pixels_left = length;
    size_t out_ptr_ix = 0;

    while (pixels_left != 0) {
        out_ptr[out_ptr_ix] =
            (ei_camera_capture_out[pixel_ix] << 16) +
            (ei_camera_capture_out[pixel_ix + 1] << 8) +
            ei_camera_capture_out[pixel_ix + 2];

        out_ptr_ix++;
        pixel_ix += 3;
        pixels_left--;
    }

    return 0;
}