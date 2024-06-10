FROM python:3.12.4-slim-bookworm as base

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PATH=/home/tsuser/.local/bin:$PATH
ENV TS_APP_ENV="docker"

# Prepare environment
RUN mkdir /tradescope \
  && apt-get update \
  && apt-get -y install sudo libatlas3-base curl sqlite3 libhdf5-serial-dev libgomp1 \
  && apt-get clean \
  && useradd -u 1000 -G sudo -U -m -s /bin/bash tsuser \
  && chown tsuser:tsuser /tradescope \
  # Allow sudoers
  && echo "tsuser ALL=(ALL) NOPASSWD: /bin/chown" >> /etc/sudoers

WORKDIR /tradescope

# Install dependencies
FROM base as python-deps
RUN  apt-get update \
  && apt-get -y install build-essential libssl-dev git libffi-dev libgfortran5 pkg-config cmake gcc \
  && apt-get clean \
  && pip install --upgrade pip wheel

# Install TA-lib
COPY build_helpers/* /tmp/
RUN cd /tmp && /tmp/install_ta-lib.sh && rm -r /tmp/*ta-lib*
ENV LD_LIBRARY_PATH /usr/local/lib

# Install dependencies
COPY --chown=tsuser:tsuser requirements.txt requirements-hyperopt.txt /tradescope/
USER tsuser
RUN  pip install --user --no-cache-dir numpy \
  && pip install --user --no-cache-dir -r requirements-hyperopt.txt

# Copy dependencies to runtime-image
FROM base as runtime-image
COPY --from=python-deps /usr/local/lib /usr/local/lib
ENV LD_LIBRARY_PATH /usr/local/lib

COPY --from=python-deps --chown=tsuser:tsuser /home/tsuser/.local /home/tsuser/.local

USER tsuser
# Install and execute
COPY --chown=tsuser:tsuser . /tradescope/

RUN pip install -e . --user --no-cache-dir --no-build-isolation \
  && mkdir /tradescope/user_data/ \
  && tradescope install-ui

ENTRYPOINT ["tradescope"]
# Default to trade mode
CMD [ "trade" ]
