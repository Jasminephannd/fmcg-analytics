"""Console logger for the pipeline"""

import logging

def get_logger(name):
    """Return a console logger at INFO level"""
    logger = logging.getLogger(name)
    if not logger.handlers:                                  # only configure once
        handler = logging.StreamHandler()                    # log to the console
        handler.setFormatter(logging.Formatter(
            fmt="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M",
        ))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger
