FPCLAC= 6550
FPLOAD= 6551
FPSTOR= 6552
FPADD= 6553
FPMULT=6554

*400
Main, FPCLAC
    FPLOAD
    addr_a
    FPADD
    addr_b
    FPSTOR
    addr_c
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
    
addr_a, a
addr_b, b
addr_c, c
$Main
