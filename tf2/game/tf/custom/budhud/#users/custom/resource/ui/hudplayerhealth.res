"Resource/UI/HudPlayerHealth.res"
{
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // Health progress bar (vertical, left of the health number)
    // PlayerStatusHealthImage is TF2's native health fill - it can only drain top-to-bottom,
    // so the bar is vertical. Its texture is made solid by materials/hud/health_color.vmt.
    // Colours are set in #users/custom/scripts/hudanimations_custom.txt
    // zpos layering
    // 1 Track (empty part of the bar)
    // 2 Fill
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    "bh_HealthBarTrack"
    {
        "ControlName"                                               "CExLabel"
        "fieldName"                                                 "bh_HealthBarTrack"
        "xpos"                                                      "75"
        "ypos"                                                      "54"
        "zpos"                                                      "1"
        "wide"                                                      "8"
        "tall"                                                      "42"
        "autoResize"                                                "0"
        "pinCorner"                                                 "0"
        "labeltext"                                                 ""
        "visible"                                                   "1"
        "enabled"                                                   "1"
        "bgcolor_override"                                          "40 40 40 200"
        "paintbackground"                                           "1"
    }

    "PlayerStatusHealthImage"
    {
        "xpos"                                                      "76"
        "ypos"                                                      "55"
        "zpos"                                                      "2"
        "wide"                                                      "6"
        "tall"                                                      "40"
        "visible"                                                   "1"
        "enabled"                                                   "1"
        "fgcolor_override"                                          "90 200 90 255"
    }
}
