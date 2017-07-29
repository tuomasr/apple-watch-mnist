import numpy
import coremltools
from keras.datasets import mnist

# Try predicting using the Core ML model
# Instantiate a model
coreml_model = coremltools.models.MLModel('mnist.mlmodel')

# input image dimensions
img_rows, img_cols = 28, 28

# the data, shuffled and split between train and test sets
_,  (X_test, y_test) = mnist.load_data()

X_test = X_test.reshape(X_test.shape[0], img_rows, img_cols, 1)
input_shape = (img_rows, img_cols, 1)

X_test = X_test.astype('float32')
X_test /= 255

#import ipdb; ipdb.set_trace()

sample_image = X_test[:2, :]



predictions = coreml_model.predict({'input_data': sample_image})