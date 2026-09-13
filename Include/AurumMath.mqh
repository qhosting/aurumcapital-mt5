#ifndef AURUM_MATH_MQH
#define AURUM_MATH_MQH
// Pure arithmetic shared with the native C++ regression harness.
double AurumFloorVolume(double requested,double minimum,double maximum,double step) {
   if(!MathIsValidNumber(requested) || !MathIsValidNumber(minimum) || !MathIsValidNumber(maximum) || !MathIsValidNumber(step)) return 0;
   if(step<=0 || minimum<=0 || maximum<minimum || requested<minimum-1e-10) return 0;
   double v=MathFloor((MathMin(requested,maximum)+1e-10)/step)*step;
   return v>=minimum-1e-10 ? v : 0;
}
double AurumRiskVolume(double budget,double loss_per_lot,double minimum,double maximum,double step) {
   if(!MathIsValidNumber(budget) || !MathIsValidNumber(loss_per_lot)) return 0;
   if(budget<=0 || loss_per_lot<=0) return 0;
   double v=AurumFloorVolume(budget/loss_per_lot,minimum,maximum,step);
   return v*loss_per_lot<=budget+1e-8 ? v : 0;
}
double AurumPartialVolume(double initial,double current,double fraction,double minimum,double maximum,double step) {
   double target=AurumFloorVolume(initial*fraction,minimum,maximum,step);
   double already=initial-current;
   double remaining=AurumFloorVolume(target-already,minimum,maximum,step);
   return remaining>0 && current-remaining>=minimum-1e-10 ? remaining : 0;
}
bool AurumSessionMinute(int minute) {
   return (minute>=75 && minute<330) || (minute>=390 && minute<690);
}
#endif
