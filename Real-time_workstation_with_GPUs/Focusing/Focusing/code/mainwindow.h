#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTimer>
#include "qcustomplot.h"

#define SHOWLENGTH 1000

namespace Ui {
	class MainWindow;
}

class MainWindow : public QMainWindow
{
	Q_OBJECT

	public:
		explicit MainWindow(int _regid,QWidget *parent = nullptr);
		~MainWindow();
		void setupScatterStyleDemo(QCustomPlot *customPlot);
		double **Buff;
		double currentdata;
		public slots:
			void selectionChanged();
		void mousePress();
		void mouseWheel();
		void graphClicked(QCPAbstractPlottable *plottable, int dataIndex);
		void realtimeDataSlot();
		void readyrealtime();
	private:
		Ui::MainWindow *ui;
		QString demoName;
		QTimer dataTimer;
		QCPItemTracer *itemDemoPhaseTracer;
		int currentDemoIndex;
		int line_number;
		unsigned  int flag;
		unsigned  int preFlag;
		int regid;

};

#endif // MAINWINDOW_H
