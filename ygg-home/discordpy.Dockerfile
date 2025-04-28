FROM docker.io/gorialis/discord.py:minimal

# Set working directory
WORKDIR /app

# Install Python dependencies separately to leverage Docker layer caching
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy source files
COPY wrapper.sh ./
COPY *.py ./

# Ensure wrapper script is executable
RUN chmod +x /app/wrapper.sh

# (Optional) Copy any other remaining files (configs, assets) if needed
# COPY . .

# Set entrypoint
CMD ["/app/wrapper.sh"]
