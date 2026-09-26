const errorHandler = (err, req, res, next) => {
  console.error(err.stack);

  // If the status code is 200 but an error was thrown, default to 500
  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  
  res.status(statusCode).json({
    success: false,
    data: null,
    message: err.message || 'Server Error',
  });
};

module.exports = errorHandler;
