#include <cmath>
#include <cassert>
#include <iostream>
#define MathIsValidNumber std::isfinite
#define MathFloor std::floor
#define MathMin std::fmin
#include "../Include/AurumMath.mqh"
int main() {
 assert(AurumRiskVolume(2,1800,.01,100,.01)==0); // $200 equity / 1%, min risk $18
 assert(std::abs(AurumRiskVolume(18,1800,.01,100,.01)-.01)<1e-10);
 assert(AurumRiskVolume(10,0,.01,100,.01)==0);
 assert(AurumRiskVolume(2,300,.01,100,.01)==0); // widened stop invalidates previous lot
 assert(std::abs(AurumFloorVolume(.017,.001,1,.001)-.017)<1e-10);
 assert(AurumFloorVolume(.24,.25,10,.25)==0);
 assert(std::abs(AurumPartialVolume(1,1,.5,.01,100,.01)-.5)<1e-10);
 assert(AurumPartialVolume(1,.5,.5,.01,100,.01)==0); // partial already realized / restart
 assert(AurumPartialVolume(.01,.01,.5,.01,100,.01)==0);
 assert(AurumSessionMinute(75) && !AurumSessionMinute(74));
 assert(!AurumSessionMinute(330) && !AurumSessionMinute(389));
 assert(AurumSessionMinute(390) && !AurumSessionMinute(690));
 for(int i=1;i<=20000;i++) {
   double budget=i*.003, loss=187.37;
   double v=AurumRiskVolume(budget,loss,.01,10,.01);
   assert(v*loss<=budget+1e-8);
 }
 std::cout<<"Aurum shared arithmetic: 20,000 budget invariants + boundary cases passed\n";
}
