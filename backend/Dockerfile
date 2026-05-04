# Kenapa pakai alpine? karna lebih ringan dan kecil ukurannya
FROM python:3.12-alpine

# Set timezone to UTC
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1

# Set timezone for Alpine & Install runtime dependencies
RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    curl \
    libpq \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

WORKDIR /app

COPY requirements.txt .

RUN echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main" > /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories \
    && apk update

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    python3-dev \
    make \
    g++ \
    git \
    postgresql-dev

# Upgrade pip
RUN pip install --upgrade pip \
    --trusted-host pypi.org \
    --trusted-host pypi.python.org \
    --trusted-host files.pythonhosted.org

# Install Python packages
RUN pip install --no-cache-dir -r requirements.txt \
    --trusted-host pypi.org \
    --trusted-host pypi.python.org \
    --trusted-host files.pythonhosted.org

# ✅ mkdir dulu, chmod setelahnya — dalam 1 RUN
RUN mkdir -p /app/core/images_folder_path_exclusive \
    /app/core/images_street_view_path \
    /app/core/images_research_coin_path \
    /app/core/images_quant_path \
    /app/core/market_outlook_path \
    /app/core/images_daily_research_path \
    /app/core/uploads_images_profile \
    && chmod -R 755 /app/core

# Clean up build dependencies
RUN apk del .build-deps

# Whitelist libary python yang boleh digunakan user
RUN pip install numpy pandas matplotlib scipy requests sympy 

# Copy application code
COPY . .

EXPOSE 8080

RUN echo "Timezone: $(date +%Z)" && date

CMD ["uvicorn", "core.main:app", "--host", "0.0.0.0", "--port", "8080"]