import numpy
import coremltools

# Convert a pretrained Keras model to a Core ML model
output_labels = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']

coreml_model = coremltools.converters.keras.convert('mnist.h5',
 													input_names='image',
 													image_input_names='image',
 													output_names='output',
 													image_scale=1/255.,
 													class_labels=output_labels
 													)

# save the model
coreml_model.save('mnist.mlmodel')

