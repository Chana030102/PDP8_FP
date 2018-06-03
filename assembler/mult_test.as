/ Program: mult_test.as
/ Date : June 1, 2018
/
/ Desc : Test FPMULT operation
/
/=================
/
/ Code Secion
/
FPCLAC= 6550
FPLOAD= 6551
FPSTOR= 6552
FPADD= 6553
FPMULT=6554

*400
Main, FPCLAC
    FPLOAD
    a
    FPMULT
    b
    FPSTOR
    c
    hlt
/
/ Data Section
/
*20
a,  201
    5000
    0
b,  201
    5000
    0
c,  0
    0
    0
    
$Main
