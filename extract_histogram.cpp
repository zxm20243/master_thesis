#include <iostream>
#include <fstream>
#include <string>
#include <opencv2/opencv.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>

#define NORM_SIZE 256
#define IMG_WIDTH NORM_SIZE
#define IMG_HEIGHT NORM_SIZE

using namespace cv;
using std::cout;
using std::endl;

Mat preprocessing(Mat image)
{
    Mat norm_image;

    // Resize shorter side to NORM_SIZE
    double scale = (double)NORM_SIZE/std::min(image.cols, image.rows);
    resize(image, norm_image, Size(), scale, scale);

    // Crop for central part of image
    Point ofs((norm_image.cols-IMG_WIDTH)/2, (norm_image.rows-IMG_HEIGHT)/2);
    norm_image = norm_image(Rect(ofs, Size(IMG_WIDTH, IMG_HEIGHT)));

    return norm_image;
}

int main(int argc, char **argv)
{
    int label;
    std::string path;
    std::fstream fin(argv[1], std::fstream::in);
    std::fstream fout(argv[2], std::fstream::out);
    fout.precision(4);

    std::vector<Mat> images;
    while(fin >> path >> label){
        Mat image = imread(path, CV_LOAD_IMAGE_COLOR);
        image = preprocessing(image);

        Mat hist;
        int dims=3, channels[]={0, 1, 2}, bins[]={16, 16, 16};
        float rgb_range[] = {0, 256};
        const float *hist_range[] = {rgb_range, rgb_range, rgb_range};
        calcHist(&image, 1, channels, Mat(), hist, dims, bins, hist_range);

        hist = hist/(IMG_WIDTH*IMG_HEIGHT);
        fout << label;
        for( int i=0; i<hist.total(); i++ ){
            if( hist.at<float>(i) > 0 ){
                fout << " " << i+1 << ":" << hist.at<float>(i);
            }
        }
        fout << endl;
    }


    return 0;
}