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
#include "XmlConfig.h"

extern vector<ROIPOSITION> roiptn;
extern vector<ROIVALUE> roivalues;
extern vector<ROIGROUP> roigroups;
MainWindow::MainWindow(int  _groupid,int _roishowlength,unsigned int _regNumber,QWidget *parent) :
	QMainWindow(parent),
    groupid(_groupid),
    roi_showlength(_roishowlength),
    regNumber(_regNumber),
	ui(new Ui::MainWindow)
{
	ui->setupUi(this);
    demoName = "Brain Area ";
    demoName += QString::number(groupid);
	setWindowTitle(demoName);
    line_number = roigroups[groupid].ROINumPerGroup;
	if(line_number>5){
		line_number=5;
	}
	Buff = new double *[line_number];
	for(int i=0; i<line_number;i++){
		Buff[i] = new double [roi_showlength];
		for(int j =0; j < roi_showlength; j++){
			Buff[i][j] = 0;
		}
	}
	currentdata = 0;
	flag = 0;
	preFlag = 0;
    //ui->customPlot
	setupScatterStyleDemo(ui->customPlot);

	statusBar()->clearMessage();

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
    QString linesname = "Brain Area "+QString::number(groupid);
    customPlot->plotLayout()->insertRow(0);
    customPlot->plotLayout()->addElement(0,0,new QCPTextElement(customPlot,linesname,QFont("sans",12,QFont::Bold)));
	ui->customPlot->setInteractions(QCP::iSelectLegend | QCP::iSelectPlottables);
	customPlot->legend->setVisible(true);
	customPlot->legend->setFont(QFont("Helvetica", 9));
	customPlot->legend->setRowSpacing(-3);
    customPlot->axisRect()->insetLayout()->setInsetAlignment(0,Qt::AlignLeft|Qt::AlignTop);

	ui->customPlot->legend->setSelectableParts(QCPLegend::spItems); // legend box shall not be selectable, only legend items

	QVector<QCPScatterStyle::ScatterShape> shapes;
	for(int i=0; i<line_number; i++){
		shapes << QCPScatterStyle::ssDisc;
	}


	QPen pen;
	// add graphs with different scatter styles:
	for (int i=0; i<line_number; ++i)
	{
		customPlot->addGraph();
		pen.setColor(QColor(qSin(i*2*0.3)*100+100, qSin(i*3*0.6+0.7)*100+100, qSin(i*4*0.4+0.6)*100+100));
		// generate data:

		//customPlot->graph()->setData(xdata[i], indata[i]);
		//   customPlot->graph()->setData(x, y);
		customPlot->graph()->rescaleAxes(true);
		customPlot->graph()->setPen(pen);
        customPlot->yAxis->setRange(0,0.5);
		QString legendname = "ROI_";
        int roid = roigroups[groupid].roiID[i];
        QString numtmp = QString::number(roid);
		legendname += numtmp;
		customPlot->graph()->setName(legendname);
		customPlot->graph()->setLineStyle(QCPGraph::lsLine);

	}

	// set blank axis lines:
	customPlot->rescaleAxes();
	customPlot->xAxis->setTicks(true);
	customPlot->yAxis->setTicks(true);
	customPlot->xAxis->setTickLabels(true);
	customPlot->yAxis->setTickLabels(true);
	connect(ui->customPlot, SIGNAL(selectionChangedByUser()), this, SLOT(selectionChanged()));
	connect(ui->customPlot, SIGNAL(mousePress(QMouseEvent*)), this, SLOT(mousePress()));
	connect(ui->customPlot, SIGNAL(mouseWheel(QWheelEvent*)), this, SLOT(mouseWheel()));
	connect(ui->customPlot, SIGNAL(plottableClick(QCPAbstractPlottable*,int,QMouseEvent*)), this, SLOT(graphClicked(QCPAbstractPlottable*,int)));
	QTimer  *qdataTimer =new QTimer(this);
	connect(qdataTimer,SIGNAL(timeout()),this,SLOT(readyrealtime()));
    qdataTimer->start(50);
	// make top right 00axes clones of bottom left axes:
	customPlot->axisRect()->setupFullAxesBox();
}
void MainWindow::readyrealtime(){
	/* currentdata += 5;
	   if(currentdata > 80)
	   currentdata = 0;*/
    flag = roigroups[groupid].resNumFlag;

    if(flag >0 && flag > preFlag){

		realtimeDataSlot();
        //if(groupid == 4)
           // cout << flag << " " << preFlag << endl;
		preFlag = flag;
	}
	ui->customPlot->replot();

}
void MainWindow::realtimeDataSlot(){

    QVector<double>  indata(roi_showlength);
    QVector<double>  xdata(roi_showlength);
	// Buff[flag] = currentdata;
	// double v_max = 0;
    if(flag <= roi_showlength){
		for (int i=0; i<line_number; ++i){
			//QPen pen;

            int j_length = flag<roigroups[groupid].ResNums[i] ? flag:roigroups[groupid].ResNums[i];
            for(int j=0; j< j_length;j++){
				xdata[j] = j;
                indata[j] = roigroups[groupid].value[i][j];
				// if(indata[j] > v_max)
                // v_max = indata[j];
            }
			//double key = flag;
			// double value_i = Buff[flag]+i*10;
            //Buff[i][flag] = roivalues[regid].value[i][flag];
           // double key = flag;
           // double value_flag = Buff[i][flag];
			//  pen.setColor(QColor(qSin(i*2*0.3)*100+100, qSin(i*3*0.6+0.7)*100+100, qSin(i*4*0.4+0.6)*100+100));
            ui->customPlot->graph(i)->setData(xdata, indata);
            //ui->customPlot->yAxis->setRange(0,value_flag);
            //ui->customPlot->xAxis->setRange(xdata[0],xdata[roi_showlength-1]);
            //ui->customPlot->graph(i)->addData(key,value_flag);
            ui->customPlot->graph(i)->rescaleAxes(true);

		}
	}
	else{
		for (int i=0; i<line_number; ++i){
			//QPen pen;
        //QVector<double>  indata(roi_showlength);
        //QVector<double>  xdata(roi_showlength);

			for(int j=0; j< roi_showlength;j++){
                int index = flag-roi_showlength + j;
				xdata[j] = index;
                if(roigroups[groupid].ResNums[i] > index)
                    indata[j] = roigroups[groupid].value[i][index];
                else
                    indata[j] = 0;
				//if(indata[j] > v_max)
				//v_max = indata[j];
            }
           // Buff[i][flag%roi_showlength] = roivalues[regid].value[i][]
            //double key = flag;
			// double value_i = Buff[flag]+i*10;

			//  pen.setColor(QColor(qSin(i*2*0.3)*100+100, qSin(i*3*0.6+0.7)*100+100, qSin(i*4*0.4+0.6)*100+100));
			ui->customPlot->graph(i)->setData(xdata, indata);
			// ui->customPlot->yAxis->setRange(0,v_max*2);
            ui->customPlot->xAxis->setRange(xdata[0],xdata[roi_showlength-1]);
			//ui->customPlot->graph(i)->addData(key,value_i);
           // ui->customPlot->graph(i)->rescaleAxes(true);

		}
	}

	//  flag ++;
	ui->customPlot->replot();
}
void MainWindow::selectionChanged()
{
	/*
	   normally, axis base line, axis tick labels and axis labels are selectable separately, but we want
	   the user only to be able to select the axis as a whole, so we tie the selected states of the tick labels
	   and the axis base line together. However, the axis label shall be selectable individually.

	   The selection state of the left and right axes shall be synchronized as well as the state of the
	   bottom and top axes.

	   Further, we want to synchronize the selection of the graphs with the selection state of the respective
	   legend item belonging to that graph. So the user can select a graph by either clicking on the graph itself
	   or on its legend item.
	 */

	// make top and bottom axes be selected synchronously, and handle axis and tick labels as one selectable object:
	if (ui->customPlot->xAxis->selectedParts().testFlag(QCPAxis::spAxis) || ui->customPlot->xAxis->selectedParts().testFlag(QCPAxis::spTickLabels) ||
			ui->customPlot->xAxis2->selectedParts().testFlag(QCPAxis::spAxis) || ui->customPlot->xAxis2->selectedParts().testFlag(QCPAxis::spTickLabels))
	{
		ui->customPlot->xAxis2->setSelectedParts(QCPAxis::spAxis|QCPAxis::spTickLabels);
		ui->customPlot->xAxis->setSelectedParts(QCPAxis::spAxis|QCPAxis::spTickLabels);
	}
	// make left and right axes be selected synchronously, and handle axis and tick labels as one selectable object:
	if (ui->customPlot->yAxis->selectedParts().testFlag(QCPAxis::spAxis) || ui->customPlot->yAxis->selectedParts().testFlag(QCPAxis::spTickLabels) ||
			ui->customPlot->yAxis2->selectedParts().testFlag(QCPAxis::spAxis) || ui->customPlot->yAxis2->selectedParts().testFlag(QCPAxis::spTickLabels))
	{
		ui->customPlot->yAxis2->setSelectedParts(QCPAxis::spAxis|QCPAxis::spTickLabels);
		ui->customPlot->yAxis->setSelectedParts(QCPAxis::spAxis|QCPAxis::spTickLabels);
	}

	// synchronize selection of graphs with selection of corresponding legend items:
	// qDebug() << " -------------  " << ui->customPlot->graphCount();
	for (int i=0; i<ui->customPlot->graphCount(); ++i)
	{
		QCPGraph *graph = ui->customPlot->graph(i);
		QCPPlottableLegendItem *item = ui->customPlot->legend->itemWithPlottable(graph);
		if (item->selected() || graph->selected())
		{
			item->setSelected(true);
			graph->setSelection(QCPDataSelection(graph->data()->dataRange()));
		}
	}
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
