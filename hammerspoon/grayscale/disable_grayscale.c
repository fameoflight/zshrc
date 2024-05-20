// clang -g -O2 -std=c11 -Wall -framework ApplicationServices disable_grayscale.c -o disable_grayscale

#include <stdio.h>
#include <ApplicationServices/ApplicationServices.h>

CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);

int main(int argc, char **argv)
{
  bool isGrayscale = CGDisplayUsesForceToGray();
  if (isGrayscale)
  {
    CGDisplayForceToGray(0);
  }

  return 0;
}
