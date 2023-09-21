import serial
import tkinter as tk
window = tk.Tk()
ser=serial.Serial("com3",38400,timeout=0.5)
def start_buttonClick():
    ser.write(b'AMD E') #external trigger mode
    ser.write(b'\x0d')
    s=ser.read(20)
    msgText.insert('insert',str(s)+"\n")
    ser.write(b'EMD S') #synchronous
    ser.write(b'\x0d')
    s=ser.read(20)
    msgText.insert('insert',str(s)+"\n")
    ser.write(b'ATP P') #external trigger input pulse polarity:POSI
    ser.write(b'\x0d')
    s=ser.read(20)
    msgText.insert('insert',str(s)+"\n")
    #ser.write(b'SMD N') #scanning mode:normal(2048x2048)
    #ser.write(b'\x0d')
    #ser.write(b'SSP H') #scan speed:standard speed
    #ser.write(b'\x0d')
    ser.write(b'ESC B') #external trigger pulse input:BNC
    ser.write(b'\x0d')
    s=ser.read(20)
    msgText.insert('insert',str(s)+"\n")
    exposure_time=exposuretimeBox.get()
    int_exposuretime=int(exposure_time)
    if 0< int_exposuretime <10000:
        u_exposuretime=exposure_time.encode('utf-8')
        #print (exposure_time)
        ser.write(b'AET ')  #set exposure time
        ser.write(u_exposuretime)
        ser.write(b'MS')
        ser.write(b'\x0d')
        s=ser.read(20)
        msgText.insert('insert',str(s)+"\n")
        ser.write(b'ACT I') #start imaging
        ser.write(b'\x0d')
        s=ser.read(20)
        msgText.insert('insert',str(s)+"\n")
        msgText.insert('insert',"camera is opened!\n")
    else:
        msgText.insert('insert',"invalid input!\n")
def  stop_buttonClick():
    ser.write(b'ACT S')
    ser.write(b'\x0d')
    s=ser.read(20)
    print (s)
    msgText.insert('insert',"camera is closed!\n")


window.title("camera control")
width,height=400,400
window.geometry('%dx%d+%d+%d' % (width,height,(window.winfo_screenwidth() - width ) / 2, (window.winfo_screenheight() - height) / 2))
window.maxsize(400,400)
window.minsize(400,400)


Label1 = tk.Label(window, text="Exposure Time(1-10000):")
Label2 = tk.Label(window, text="(ms)")
exposuretimeBox=tk.Entry(window)



start_button=tk.Button(window, text="start", command=start_buttonClick)
stop_button=tk.Button(window, text="stop", command=stop_buttonClick)
msgText=tk.Text(window)

Label1.place(x=30,y=30,width=150,height=20)
exposuretimeBox.place(x=190,y=30,width=100,height=20)
Label2.place(x=300,y=30,width=50,height=20)
#Label2.pack(padx=20,pady=200)
start_button.place(x=80,y=90,width=70,height=20)
stop_button.place(x=200,y=90,width=70,height=20)
msgText.place(x=30,y=150,width=340,height=200)
#msgLabel.pack()

window.mainloop()
