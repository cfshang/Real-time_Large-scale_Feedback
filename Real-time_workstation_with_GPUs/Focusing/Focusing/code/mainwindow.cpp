#include "mainwindow.h"
#include "ui_mainwindow.h"
#include "qcustomplot.h"
#include <QDebug>
#include <QDesktopWidget>
#include <QScreen>
#include <QMessageBox>
#include <QMetaEnum>
#include <QtXml>
#include <QDomDocument>
#include "function.h"

MainWindow::MainWindow(int  _regid,QWidget *parent) :
	QMainWindow(parent),
	regid(_regid),
	ui(new Ui::MainWindow)
{


	ui->customPlot->replot();
}
void MainWindow::setupScatterStyleDemo(QCustomPlot *customPlot)
{

	/*QFile roiConfFile("ROIConf.xml");
	  if(!roiConfFile.open(QFile::ReadOnly))
	  {
	  qDebug() << "can not open ROIConf.xml file!" << endl;
	  return;
	  }
	  QDomDocument doc;
	  if(!doc.setContent(&roiConfFile)){
	  roiConfFile.close();
	  return;
	  }
	  roiConfFile.close();

	  QDomElement root = doc.documentElement();
	// qDebug() << root.nodeName() << endl;

	QDomNode node = root.firstChild();

	QDomElement e = node.toElement();
	QString roifilepath = e.toElement().text();
	qDebug() << roifilepath << endl;

	demoName += e.toElement().text();
	demoName += " chart";
	QFile file(roifilepath);
	if(!file.open(QIODevice::ReadOnly | QIODevice::Text)){
	qDebug() << "can not open file!" << endl;
	return;
	}
	QTextStream infile(&file);
	line_number = 0;
	QVector< QVector<double> > indata;
	QVector< QVector<double> > xdata;

	while(!infile.atEnd()){
	QString line = infile.readLine();
	QStringList str_list = line.split(" ");
	QVector<double> tmpdata;
	QVector<double> xtmpdata;
	for(int i=0; i<str_list.length(); i++){
	double str_data = str_list[i].toDouble();
	tmpdata.push_back(str_data);
	xtmpdata.push_back(i+1);

	}
	tmpdata.pop_back();
	indata.push_back(tmpdata);
	line_number++;
	xtmpdata.pop_back();
	xdata.push_back(xtmpdata);

	}*/


}
void MainWindow::readyrealtime(){
	/* currentdata += 5;
	   if(currentdata > 80)
	   currentdata = 0;*/

	ui->customPlot->replot();

}
void MainWindow::realtimeDataSlot(){


	ui->customPlot->replot();
}
void MainWindow::selectionChanged()
{

}
void MainWindow::mousePress()
{
	// if an axis is selected, only allow the direction of that axis to be dragged
	// if no axis is selected, both directions may be dragged

	if (ui->customPlot->xAxis->selectedParts().testFlag(QCPAxis::spAxis))
		ui->customPlot->axisRect()->setRangeDrag(ui->customPlot->xAxis->orientation());
	else if (ui->customPlot->yAxis->selectedParts().testFlag(QCPAxis::spAxis))
		ui->customPlot->axisRect()->setRangeDrag(ui->customPlot->yAxis->orientation());
	else
		ui->customPlot->axisRect()->setRangeDrag(Qt::Horizontal|Qt::Vertical);
}
void MainWindow::mouseWheel()
{
	// if an axis is selected, only allow the direction of that axis to be zoomed
	// if no axis is selected, both directions may be zoomed

	if (ui->customPlot->xAxis->selectedParts().testFlag(QCPAxis::spAxis))
		ui->customPlot->axisRect()->setRangeZoom(ui->customPlot->xAxis->orientation());
	else if (ui->customPlot->yAxis->selectedParts().testFlag(QCPAxis::spAxis))
		ui->customPlot->axisRect()->setRangeZoom(ui->customPlot->yAxis->orientation());
	else
		ui->customPlot->axisRect()->setRangeZoom(Qt::Horizontal|Qt::Vertical);
}
void MainWindow::graphClicked(QCPAbstractPlottable *plottable, int dataIndex)
{
	// since we know we only have QCPGraphs in the plot, we can immediately access interface1D()
	// usually it's better to first check whether interface1D() returns non-zero, and only then use it.
	double dataValue = plottable->interface1D()->dataMainValue(dataIndex);
	QString message = QString("Clicked on graph '%1' at data point #%2 with value %3.").arg(plottable->name()).arg(dataIndex).arg(dataValue);
	ui->statusBar->showMessage(message, 2500);
}
MainWindow::~MainWindow()
{
	delete ui;
}
