const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

const VERSION = process.env.npm_package_version;
if (!VERSION) {
    console.error('Error: npm_package_version not found');
    process.exit(1);
}

// __dirname points to the package root when installed via npm
const BIN_DIR = path.join(__dirname, 'bin');
const BIN_PATH = path.join(BIN_DIR, 'gitb');
const RELEASE_URL = `https://github.com/maxbolgarin/gitbasher/releases/download/v${VERSION}/gitb`;

// Ensure bin directory exists
if (!fs.existsSync(BIN_DIR)) {
    fs.mkdirSync(BIN_DIR, { recursive: true });
}

// Download function with redirect handling
function download(url, outputPath, maxRedirects = 5) {
    return new Promise((resolve, reject) => {
        if (maxRedirects === 0) {
            reject(new Error('Too many redirects'));
            return;
        }

        const client = url.startsWith('https') ? https : http;
        const file = fs.createWriteStream(outputPath);
        let downloadedBytes = 0;
        let totalBytes = 0;

        client.get(url, (response) => {
            // Handle redirects
            if (response.statusCode === 301 || response.statusCode === 302 || response.statusCode === 307 || response.statusCode === 308) {
                file.close();
                fs.unlinkSync(outputPath);
                const redirectUrl = response.headers.location;
                if (!redirectUrl) {
                    reject(new Error('Redirect location not found'));
                    return;
                }
                // Resolve relative redirects
                const redirectUrlFull = redirectUrl.startsWith('http') 
                    ? redirectUrl 
                    : new URL(redirectUrl, url).href;
                return download(redirectUrlFull, outputPath, maxRedirects - 1)
                    .then(resolve)
                    .catch(reject);
            }

            // Handle errors
            if (response.statusCode !== 200) {
                file.close();
                fs.unlinkSync(outputPath);
                reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
                return;
            }

            // Track download progress
            totalBytes = parseInt(response.headers['content-length'] || '0', 10);
            if (totalBytes > 0) {
                response.on('data', (chunk) => {
                    downloadedBytes += chunk.length;
                });
            }

            // Pipe response to file
            response.pipe(file);

            file.on('finish', () => {
                file.close();
                fs.chmodSync(outputPath, 0o755);
                if (totalBytes > 0) {
                    const sizeKB = (downloadedBytes / 1024).toFixed(1);
                    console.log(`✓ Downloaded ${sizeKB}KB`);
                } else {
                    console.log('✓ Download complete');
                }
                resolve();
            });
        }).on('error', (err) => {
            file.close();
            if (fs.existsSync(outputPath)) {
                fs.unlinkSync(outputPath);
            }
            reject(err);
        });
    });
}

// Download the release asset
console.log(`Downloading gitbasher v${VERSION}...`);
download(RELEASE_URL, BIN_PATH)
    .catch((err) => {
        console.error(`✗ Error downloading release: ${err.message}`);
        process.exit(1);
    });