#include QMK_KEYBOARD_H
#include "version.h"
#define MOON_LED_LEVEL LED_LEVEL
#ifndef ZSA_SAFE_RANGE
#define ZSA_SAFE_RANGE SAFE_RANGE
#endif

enum custom_keycodes {
  RGB_SLD = ZSA_SAFE_RANGE,
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_voyager(
    KC_ESCAPE,      KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_DELETE,
    QK_CAPS_WORD_TOGGLE,KC_Q,       KC_W,           KC_E,           KC_R,           KC_T,                                           KC_Y,           KC_U,           KC_I,           KC_O,           KC_P,           KC_RIGHT_SHIFT,
    KC_LEFT_SHIFT,  KC_A,           MT(MOD_LCTL, KC_S),MT(MOD_LALT, KC_D),KC_F,       KC_G,                                           KC_H,           KC_J,           MT(MOD_RALT, KC_K),MT(MOD_RCTL, KC_L),KC_COLN,        KC_TAB,
    MO(3),          KC_Z,           KC_X,           KC_C,           KC_V,           KC_B,                                           KC_N,           KC_M,           KC_COMMA,       KC_DOT,         KC_DQUO,        KC_ENTER,
                                                    MT(MOD_LGUI, KC_ENTER),LT(1, KC_ESCAPE),                                LT(2, KC_BSPC), KC_SPACE
  ),
  [1] = LAYOUT_voyager(
    KC_TRANSPARENT, KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,                                          KC_F6,          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_EXLM,        KC_AT,          KC_HASH,        KC_DLR,         KC_PERC,                                        KC_CIRC,        KC_AMPR,        KC_ASTR,        KC_PIPE,        KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_MINUS,       KC_UNDS,        KC_LPRN,        KC_LBRC,        KC_LCBR,                                        KC_RCBR,        KC_RBRC,        KC_RPRN,        KC_QUES,        KC_SCLN,        KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_GRAVE,       KC_EQUAL,       KC_TILD,        KC_PLUS,                                        KC_SLASH,       KC_BSLS,        KC_LABK,        KC_RABK,        KC_QUOTE,       KC_TRANSPARENT, 
                                                    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_0
  ),
  [2] = LAYOUT_voyager(
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_HOME,        KC_PGDN,        KC_PGUP,        KC_END,         KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_LCTL,        KC_LALT,        KC_LSFT,        KC_TRANSPARENT,                                 KC_LEFT,        KC_DOWN,        KC_UP,          KC_RIGHT,       KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, LGUI(KC_Z),     LGUI(KC_X),     LGUI(KC_C),     LGUI(KC_V),     KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_DELETE,      KC_TRANSPARENT,
                                                    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [3] = LAYOUT_voyager(
    KC_TRANSPARENT, KC_F11,         KC_F12,         KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_BRIU,        KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_WH_U,        KC_WH_D,        KC_BTN3,        KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,
    KC_TRANSPARENT, KC_MPRV,        KC_MPLY,        KC_MNXT,        KC_BRID,        KC_TRANSPARENT,                                 KC_MS_L,        KC_MS_D,        KC_MS_U,        KC_MS_R,        KC_TRANSPARENT, KC_TRANSPARENT,
    KC_TRANSPARENT, KC_MUTE,        KC_VOLD,        KC_VOLU,        LGUI(LSFT(LCTL(KC_3))), LGUI(LSFT(LCTL(KC_4))),                 KC_TRANSPARENT, KC_BTN1,        KC_BTN2,        KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,
                                                    KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT
  ),
};

const char chordal_hold_layout[MATRIX_ROWS][MATRIX_COLS] PROGMEM = LAYOUT(
  'L', 'L', 'L', 'L', 'L', 'L', 'R', 'R', 'R', 'R', 'R', 'R', 
  'L', 'L', 'L', 'L', 'L', 'L', 'R', 'R', 'R', 'R', 'R', 'R', 
  'L', 'L', 'L', 'L', 'L', 'L', 'R', 'R', 'R', 'R', 'R', 'R', 
  'L', 'L', 'L', 'L', 'L', 'L', 'R', 'R', 'R', 'R', 'R', 'R', 
  '*', '*', '*', '*'
);





extern rgb_config_t rgb_matrix_config;

RGB hsv_to_rgb_with_value(HSV hsv) {
  RGB rgb = hsv_to_rgb( hsv );
  float f = (float)rgb_matrix_config.hsv.v / UINT8_MAX;
  return (RGB){ f * rgb.r, f * rgb.g, f * rgb.b };
}

void keyboard_post_init_user(void) {
  rgb_matrix_enable();
}

const uint8_t PROGMEM ledmap[][RGB_MATRIX_LED_COUNT][3] = {
    [0] = { {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255}, {87,255,255} },

    [1] = { {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255}, {131,254,255} },

    [2] = { {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204}, {255,218,204} },

    [3] = { {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255}, {40,255,255} },

};

void set_layer_color(int layer) {
  for (int i = 0; i < RGB_MATRIX_LED_COUNT; i++) {
    HSV hsv = {
      .h = pgm_read_byte(&ledmap[layer][i][0]),
      .s = pgm_read_byte(&ledmap[layer][i][1]),
      .v = pgm_read_byte(&ledmap[layer][i][2]),
    };
    if (!hsv.h && !hsv.s && !hsv.v) {
        rgb_matrix_set_color( i, 0, 0, 0 );
    } else {
        RGB rgb = hsv_to_rgb_with_value(hsv);
        rgb_matrix_set_color(i, rgb.r, rgb.g, rgb.b);
    }
  }
}

bool rgb_matrix_indicators_user(void) {
  if (rawhid_state.rgb_control) {
      return false;
  }
  if (!keyboard_config.disable_layer_led) { 
    switch (biton32(layer_state)) {
      case 0:
        set_layer_color(0);
        break;
      case 1:
        set_layer_color(1);
        break;
      case 2:
        set_layer_color(2);
        break;
      case 3:
        set_layer_color(3);
        break;
     default:
        if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
          rgb_matrix_set_color_all(0, 0, 0);
        }
    }
  } else {
    if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
      rgb_matrix_set_color_all(0, 0, 0);
    }
  }

  return true;
}


bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
    case RGB_SLD:
      if (record->event.pressed) {
        rgblight_mode(1);
      }
      return false;
  }
  return true;
}
