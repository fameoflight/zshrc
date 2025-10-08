#!/usr/bin/env python3

from ctypes import (CDLL, util, c_void_p, c_uint32,
                    c_int, c_bool, POINTER, byref)

cg = CDLL(util.find_library('CoreGraphics'))

cg.CGBeginDisplayConfiguration.argtypes = [POINTER(c_void_p)]
cg.CGBeginDisplayConfiguration.restype = c_int
cg.CGCompleteDisplayConfiguration.argtypes = [c_void_p, c_int]
cg.CGCompleteDisplayConfiguration.restype = c_int
cg.CGCancelDisplayConfiguration.argtypes = [c_void_p]
cg.CGCancelDisplayConfiguration.restype = c_int
cg.CGSConfigureDisplayEnabled.argtypes = [c_void_p, c_uint32, c_bool]
cg.CGSConfigureDisplayEnabled.restype = c_int


def enable_display(display_id):
    config_ref = c_void_p()
    if cg.CGBeginDisplayConfiguration(byref(config_ref)) != 0:
        return False
    if cg.CGSConfigureDisplayEnabled:
        if cg.CGSConfigureDisplayEnabled(config_ref, display_id, True) != 0:
            cg.CGCancelDisplayConfiguration(config_ref)
            return False
    cg.CGCompleteDisplayConfiguration(config_ref, 0)
    return True


def reset_displays():
    """Try to enable displays with IDs 1-20 (expanded range)"""
    enabled_count = 0
    for display_id in range(1, 99):
        if enable_display(display_id):
            enabled_count += 1
    return enabled_count


def enable_specific_displays(display_ids):
    """Enable specific display IDs"""
    enabled_count = 0
    for display_id in display_ids:
        try:
            if enable_display(int(display_id)):
                enabled_count += 1
        except (ValueError, TypeError):
            continue
    return enabled_count


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        # Enable specific display IDs provided as arguments
        display_ids = sys.argv[1:]
        print(f"Enabling specific display IDs: {display_ids}")
        enabled = enable_specific_displays(display_ids)
        print(f"Successfully enabled {enabled} displays")
    else:
        # Reset all displays (default behavior)
        print("Resetting all displays...")
        enabled = reset_displays()
        print(f"Successfully enabled {enabled} displays")
