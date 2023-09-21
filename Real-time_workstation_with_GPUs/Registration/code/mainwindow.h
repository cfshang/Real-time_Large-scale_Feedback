#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTimer>
#include "qcustomplot.h"

#define SHOWLENGTH 1000
#define GROUPNUM 20
namespace Ui {
	class MainWindow;
}

class MainWindow : public QMainWindow
{
	Q_OBJECT

	public:
        explicit MainWindow(int _roishowlength,unsigned int _regNumber,QWidget *parent = nullptr);
		~MainWindow();
        void setupScatterStyleDemo();
		double **Buff;
        double currentdata[GROUPNUM];
		public slots:
			void selectionChanged();
            void mousePress();
            void mouseWheel();

            void selectionChanged1();
            void mousePress1();
            void mouseWheel1();

            void selectionChanged2();
            void mousePress2();
            void mouseWheel2();

            void selectionChanged3();
            void mousePress3();
            void mouseWheel3();
            void selectionChanged4();
            void mousePress4();
            void mouseWheel4();

            void selectionChanged5();
            void mousePress5();
            void mouseWheel5();

            void selectionChanged6();
            void mousePress6();
            void mouseWheel6();

            void selectionChanged7();
            void mousePress7();
            void mouseWheel7();
            void selectionChanged8();
            void mousePress8();
            void mouseWheel8();

            void selectionChanged9();
            void mousePress9();
            void mouseWheel9();

            void selectionChanged10();
            void mousePress10();
            void mouseWheel10();

            void selectionChanged11();
            void mousePress11();
            void mouseWheel11();
            void selectionChanged12();
            void mousePress12();
            void mouseWheel12();

            void selectionChanged13();
            void mousePress13();
            void mouseWheel13();

            void selectionChanged14();
            void mousePress14();
            void mouseWheel14();

            void selectionChanged15();
            void mousePress15();
            void mouseWheel15();
            void selectionChanged16();
            void mousePress16();
            void mouseWheel16();

            void selectionChanged17();
            void mousePress17();
            void mouseWheel17();

            void selectionChanged18();
            void mousePress18();
            void mouseWheel18();

            void selectionChanged19();
            void mousePress19();
            void mouseWheel19();

		void graphClicked(QCPAbstractPlottable *plottable, int dataIndex);
        void realtimeDataSlot(int groupid);
        void readyrealtime();
	private:
		Ui::MainWindow *ui;
		QString demoName;
        QTimer dataTimer[GROUPNUM];
        QCPItemTracer *itemDemoPhaseTracer[GROUPNUM];
        int currentDemoIndex[GROUPNUM];
        int line_number[GROUPNUM];
        unsigned  int flag[GROUPNUM];
        unsigned  int preFlag[GROUPNUM];
        int groupid;
        unsigned int roi_showlength;
        unsigned int regNumber;
        int roiGroupNumber;

};

#endif // MAINWINDOW_H
