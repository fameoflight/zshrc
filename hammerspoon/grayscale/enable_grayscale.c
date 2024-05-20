// clang -g -O2 -std=c11 -Wall -framework ApplicationServices enable_grayscale.c -o enable_grayscale

#include <stdio.h>
#include <ApplicationServices/ApplicationServices.h>

CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);

int main(int argc, char **argv)
{
    bool isGrayscale = CGDisplayUsesForceToGray();
    if (!isGrayscale)
    {
        CGDisplayForceToGray(TRUE);
    }

    return 0;
}
