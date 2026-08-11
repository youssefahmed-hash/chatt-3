export const uploadImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        message: 'No image uploaded',
      });
    }

    const imageUrl =
      `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    return res.status(200).json({
      url: imageUrl,
    });
  } catch (error) {
    return res.status(500).json({
      message: error.message,
    });
  }
};