/ Program : test2.as
/ Date : May 2, 2018
/ 
/ Desc : Test the FPLOAD and FPSTOR operations
/
/==========================
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
    FPADD
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
b,  203
    1500
    0
c,  0
    0
    0
    
$Main
