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
*20
d, 5
e, -1
f, 0

*400
Main, 0
    cla
    tad d
Dec, tad e
    sza
    jmp Dec
    hlt
$Main
