# Base Image
FROM node:22-alpine 

# Working Directory
WORKDIR /app 

# Copy package files
COPY package*.json ./ 

# Install dependencies
RUN npm install

# Copy application code
COPY . . 

# Expose application port
EXPOSE 5000

# Start application
CMD [ "npm", "start" ]