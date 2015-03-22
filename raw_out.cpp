#include <iostream>
#include <fstream>
#include <string>
#include <opencv2/opencv.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>

#define WIDTH 256
#define HEIGHT 256

int main(int argc, char **argv)
{
    if(argc != 3){
        printf("Usage: %s image_list data_filename\n", argv[0]);
        return -1;
    }

    int label;
    std::string path;
    std::fstream fin(argv[1], std::fstream::in);
    std::fstream fout(argv[2], std::fstream::out);

    fout.precision(4);
    while(fin >> path >> label){
        cv::Mat image, norm_img;
        image = cv::imread(path, CV_LOAD_IMAGE_COLOR);
        cv::resize(image, norm_img, cv::Size(HEIGHT, WIDTH));
        norm_img = norm_img.reshape(1, 1);

        fout << label;
        for( int i=0; i<norm_img.total(); i++ ){
            if( norm_img.at<uchar>(i)!=0 )
                fout << " " << i+1 << ":" << (double)norm_img.at<uchar>(i)/255;
        }
        fout << std::endl;
        std::cout << path << std::endl;
    }
    fin.close();

    return 0;
}