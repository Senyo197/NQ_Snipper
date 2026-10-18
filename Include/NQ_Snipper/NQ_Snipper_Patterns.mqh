#ifndef __NQ_SNIPPER_PATTERNS__
#define __NQ_SNIPPER_PATTERNS__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_Doubles.mqh"
#include "NQ_Snipper_LegKnee.mqh"
#include "NQ_Snipper_TailBody.mqh"



//==================================================
// PATTERN NAME
//==================================================

string PatternName(
   int pattern
)
{
   switch(pattern)
   {
      case PATTERN_DOUBLE_TOP:
         return "DOUBLE TOP";


      case PATTERN_DOUBLE_BOTTOM:
         return "DOUBLE BOTTOM";


      case PATTERN_LEG_KNEE_TOP:
         return "LEG & KNEE TOP";


      case PATTERN_LEG_KNEE_BOTTOM:
         return "LEG & KNEE BOTTOM";


      case PATTERN_TAIL_BODY_TOP:
         return "TAIL & BODY TOP";


      case PATTERN_TAIL_BODY_BOTTOM:
         return "TAIL & BODY BOTTOM";


      default:
         return "NONE";
   }
}

#endif
