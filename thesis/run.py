#!/usr/bin/python
# -*- coding: utf-8 -*-

import argparse
import os
import warnings

import numpy as np

import descriptor
from util import *


def extract_instance_wise(filename, batchsize):
    dataset = {}
    with open(filename, 'r') as fin:
        for line_idx, line in enumerate(fin, 1):
            path, label = line.strip().split(' ')
            data = descriptor.instance_descriptor(label, path)

            # Add image descriptor to update dataset 
            for name, value in data.items():
                dataset.setdefault(name, []).append(value)

            # With each batch, print progress report
            if line_idx % batchsize == 0: 
                print "line {0} is done".format(line_idx)

    # Convert to numpy array for furthur usage
    for name in dataset:
        dataset[name] = np.array(dataset[name])

    return dataset
 

def load_dataset(fin):
    prefix = os.path.basename(fin).partition('.')[0]

    try: 
        # Warm start at pre-extract dataset
        dataset = {}
        with np.load(prefix + ".npz") as fin:
            for name in fin.files:
                dataset[name] = fin[name]
    except IOError:
        # Cold start
        dataset = extract_instance_wise(fin, batchsize=5)
        np.savez_compressed(prefix, **dataset)
        for name in dataset:
            if name != 'label':
                filename = "{0}_{1}.dat".format(prefix, name)
                svm_write_problem(filename, dataset['label'], dataset[name])
    return dataset


if __name__ == "__main__":

    # Parse argument
    warnings.simplefilter(action="ignore", category=FutureWarning)
    parser = argparse.ArgumentParser()
    parser.add_argument("fin", metavar="image_list", 
                        help="list with path followed by label")

    args = parser.parse_args()
    dataset = load_dataset(args.fin)
