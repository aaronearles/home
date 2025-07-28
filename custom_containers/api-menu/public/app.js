// Main application logic
class APIMenuApp {
    constructor() {
        this.configManager = new ConfigManager();
        this.currentEditId = null;
        this.statusPolling = new Map(); // Track status polling for toggles
        
        this.initializeApp();
        this.bindEvents();
        this.loadControls();
    }

    initializeApp() {
        // Get DOM elements
        this.controlsGrid = document.getElementById('controls-grid');
        this.modal = document.getElementById('settings-modal');
        this.settingsForm = document.getElementById('settings-form');
        this.modalTitle = document.getElementById('modal-title');
        
        // Response modal elements
        this.responseModal = document.getElementById('response-modal');
        this.responseTitle = document.getElementById('response-title');
        this.statusBadge = document.getElementById('status-badge');
        this.statusText = document.getElementById('status-text');
        this.responseBody = document.getElementById('response-body');
        this.responseHeaders = document.getElementById('response-headers');
        this.requestUrl = document.getElementById('request-url');
        this.requestMethod = document.getElementById('request-method');
        this.requestHeaders = document.getElementById('request-headers');
        this.requestBody = document.getElementById('request-body');
        
        // Form elements
        this.controlLabel = document.getElementById('control-label');
        this.apiUrl = document.getElementById('api-url');
        this.httpMethod = document.getElementById('http-method');
        this.statusUrl = document.getElementById('status-url');
        this.headers = document.getElementById('headers');
        this.body = document.getElementById('body');
        this.toggleStatusGroup = document.getElementById('toggle-status-group');
        
        // Bind response modal tab events
        this.bindResponseModalEvents();
    }

    bindEvents() {
        // Add button/toggle events
        document.getElementById('add-button').addEventListener('click', () => {
            this.openSettingsModal('button');
        });

        document.getElementById('add-toggle').addEventListener('click', () => {
            this.openSettingsModal('toggle');
        });

        // Modal events
        document.querySelector('.close').addEventListener('click', () => {
            this.closeModal();
        });

        // Close modal when clicking outside
        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.closeModal();
            }
        });

        // Form submission
        this.settingsForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.saveControl();
        });

        // Delete control
        document.getElementById('delete-control').addEventListener('click', () => {
            this.deleteControl();
        });

        // Export/Import events
        document.getElementById('export-config').addEventListener('click', () => {
            this.configManager.exportConfig();
            this.showFeedback('Configuration exported successfully', 'success');
        });

        document.getElementById('import-config').addEventListener('click', () => {
            document.getElementById('import-file').click();
        });

        document.getElementById('import-file').addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                this.importConfig(e.target.files[0]);
            }
        });

        // ESC key to close modal
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.modal.style.display === 'block') {
                this.closeModal();
            }
        });
    }

    async importConfig(file) {
        try {
            await this.configManager.importConfig(file);
            this.loadControls();
            this.showFeedback('Configuration imported successfully', 'success');
        } catch (error) {
            this.showFeedback('Error importing configuration: ' + error.message, 'error');
        }
    }

    openSettingsModal(type, controlId = null) {
        this.currentEditId = controlId;
        this.currentType = type;
        
        // Set modal title
        if (controlId) {
            this.modalTitle.textContent = 'Edit ' + (type === 'button' ? 'Button' : 'Toggle');
            document.getElementById('delete-control').style.display = 'block';
        } else {
            this.modalTitle.textContent = 'Add ' + (type === 'button' ? 'Button' : 'Toggle');
            document.getElementById('delete-control').style.display = 'none';
        }

        // Show/hide toggle-specific fields
        if (type === 'toggle') {
            this.toggleStatusGroup.style.display = 'block';
        } else {
            this.toggleStatusGroup.style.display = 'none';
        }

        // Load existing data if editing
        if (controlId) {
            const control = this.configManager.getControl(controlId);
            if (control) {
                this.controlLabel.value = control.label || '';
                this.apiUrl.value = control.apiUrl || '';
                this.httpMethod.value = control.method || 'POST';
                this.statusUrl.value = control.statusUrl || '';
                this.headers.value = control.headers || '';
                this.body.value = control.body || '';
            }
        } else {
            // Clear form for new control
            this.settingsForm.reset();
            this.httpMethod.value = type === 'toggle' ? 'POST' : 'POST';
        }

        this.modal.style.display = 'block';
    }

    closeModal() {
        this.modal.style.display = 'none';
        this.currentEditId = null;
        this.currentType = null;
    }

    saveControl() {
        const controlData = {
            type: this.currentType,
            label: this.controlLabel.value.trim(),
            apiUrl: this.apiUrl.value.trim(),
            method: this.httpMethod.value,
            statusUrl: this.statusUrl.value.trim(),
            headers: this.headers.value.trim(),
            body: this.body.value.trim()
        };

        // Validate control
        const errors = this.configManager.validateControl(controlData);
        if (errors.length > 0) {
            this.showFeedback('Validation errors: ' + errors.join(', '), 'error');
            return;
        }

        try {
            if (this.currentEditId) {
                // Update existing control
                this.configManager.updateControl(this.currentEditId, controlData);
                this.showFeedback('Control updated successfully', 'success');
            } else {
                // Add new control
                this.configManager.addControl(controlData);
                this.showFeedback('Control added successfully', 'success');
            }

            this.closeModal();
            this.loadControls();
        } catch (error) {
            this.showFeedback('Error saving control: ' + error.message, 'error');
        }
    }

    deleteControl() {
        if (!this.currentEditId) return;

        if (confirm('Are you sure you want to delete this control?')) {
            // Stop any status polling for this control
            if (this.statusPolling.has(this.currentEditId)) {
                clearInterval(this.statusPolling.get(this.currentEditId));
                this.statusPolling.delete(this.currentEditId);
            }

            this.configManager.deleteControl(this.currentEditId);
            this.closeModal();
            this.loadControls();
            this.showFeedback('Control deleted successfully', 'success');
        }
    }

    loadControls() {
        // Clear existing controls
        this.controlsGrid.innerHTML = '';

        // Stop all status polling
        this.statusPolling.forEach(interval => clearInterval(interval));
        this.statusPolling.clear();

        // Load and render all controls
        const controls = this.configManager.getControls();
        controls.forEach(control => {
            this.renderControl(control);
        });
    }

    renderControl(control) {
        const controlElement = document.createElement('div');
        controlElement.className = 'control-item';
        controlElement.dataset.id = control.id;

        if (control.type === 'button') {
            controlElement.innerHTML = this.renderButton(control);
        } else if (control.type === 'toggle') {
            controlElement.innerHTML = this.renderToggle(control);
        }

        this.controlsGrid.appendChild(controlElement);

        // Bind events
        this.bindControlEvents(control);

        // Start status polling for toggles
        if (control.type === 'toggle' && control.statusUrl) {
            this.startStatusPolling(control);
        }
    }

    renderButton(control) {
        return `
            <div class="control-header">
                <span class="control-label">${this.escapeHtml(control.label)}</span>
                <button class="settings-btn" data-id="${control.id}" data-type="button">⚙️</button>
            </div>
            <button class="action-button" data-id="${control.id}">
                ${this.escapeHtml(control.label)}
            </button>
        `;
    }

    renderToggle(control) {
        return `
            <div class="control-header">
                <span class="control-label">${this.escapeHtml(control.label)}</span>
                <button class="settings-btn" data-id="${control.id}" data-type="toggle">⚙️</button>
            </div>
            <div class="toggle-container">
                <div class="toggle-switch" data-id="${control.id}">
                </div>
                <div class="status-indicator loading" data-id="${control.id}"></div>
                <span class="status-text" data-id="${control.id}">Checking...</span>
            </div>
        `;
    }

    bindControlEvents(control) {
        const controlElement = document.querySelector(`[data-id="${control.id}"]`);
        
        // Settings button
        const settingsBtn = controlElement.querySelector('.settings-btn');
        settingsBtn.addEventListener('click', () => {
            this.openSettingsModal(control.type, control.id);
        });

        if (control.type === 'button') {
            // Action button
            const actionBtn = controlElement.querySelector('.action-button');
            actionBtn.addEventListener('click', () => {
                this.executeButtonAction(control);
            });
        } else if (control.type === 'toggle') {
            // Toggle switch
            const toggleSwitch = controlElement.querySelector('.toggle-switch');
            toggleSwitch.addEventListener('click', () => {
                this.executeToggleAction(control);
            });
        }
    }

    async executeButtonAction(control) {
        const button = document.querySelector(`.action-button[data-id="${control.id}"]`);
        
        try {
            button.classList.add('loading');
            button.disabled = true;

            const { response, error, requestInfo } = await this.makeApiCallWithDetails(control);
            
            // Show response modal
            this.showResponseModal(control, { response, error, requestInfo });
            
            if (response && response.ok) {
                this.showFeedback(`${control.label} executed successfully`, 'success');
            }
        } catch (error) {
            this.showFeedback(`Error executing ${control.label}: ${error.message}`, 'error');
        } finally {
            button.classList.remove('loading');
            button.disabled = false;
        }
    }

    async executeToggleAction(control) {
        const indicator = document.querySelector(`.status-indicator[data-id="${control.id}"]`);
        const statusText = document.querySelector(`.status-text[data-id="${control.id}"]`);
        
        try {
            indicator.className = 'status-indicator loading';
            statusText.textContent = 'Updating...';

            const { response, error, requestInfo } = await this.makeApiCallWithDetails(control);
            
            // Show response modal
            this.showResponseModal(control, { response, error, requestInfo });
            
            if (response && response.ok) {
                this.showFeedback(`${control.label} toggled successfully`, 'success');
                
                // Update status after a short delay
                setTimeout(() => {
                    this.updateToggleStatus(control);
                }, 1000);
            } else {
                indicator.className = 'status-indicator off';
                statusText.textContent = 'Error';
            }
        } catch (error) {
            this.showFeedback(`Error toggling ${control.label}: ${error.message}`, 'error');
            indicator.className = 'status-indicator off';
            statusText.textContent = 'Error';
        }
    }

    async makeApiCall(control) {
        const options = {
            method: control.method,
            headers: {
                'Content-Type': 'application/json',
                ...this.parseHeaders(control.headers)
            }
        };

        if (control.body && ['POST', 'PUT'].includes(control.method)) {
            options.body = control.body;
        }

        return fetch(control.apiUrl, options);
    }

    async updateToggleStatus(control) {
        if (!control.statusUrl) return;

        const toggleSwitch = document.querySelector(`.toggle-switch[data-id="${control.id}"]`);
        const indicator = document.querySelector(`.status-indicator[data-id="${control.id}"]`);
        const statusText = document.querySelector(`.status-text[data-id="${control.id}"]`);

        try {
            // Use the proxy for status checks too
            const proxyPayload = {
                url: control.statusUrl,
                method: 'GET',
                headers: this.parseHeaders(control.headers)
            };

            const proxyResponse = await fetch('/api/proxy', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(proxyPayload)
            });

            if (proxyResponse.ok) {
                const proxyData = await proxyResponse.json();
                
                if (proxyData.ok) {
                    const data = proxyData.body;
                    
                    // Try to determine status from response
                    // Look for common boolean fields
                    let isOn = false;
                    if (typeof data === 'boolean') {
                        isOn = data;
                    } else if (data.status !== undefined) {
                        isOn = data.status === true || data.status === 'on' || data.status === 'true';
                    } else if (data.state !== undefined) {
                        isOn = data.state === true || data.state === 'on' || data.state === 'true';
                    } else if (data.value !== undefined) {
                        isOn = data.value === true || data.value === 'on' || data.value === 'true';
                    }

                    this.updateToggleUI(control.id, isOn);
                } else {
                    throw new Error(`HTTP ${proxyData.status}`);
                }
            } else {
                throw new Error('Proxy request failed');
            }
        } catch (error) {
            console.error('Error checking status:', error);
            indicator.className = 'status-indicator off';
            statusText.textContent = 'Unknown';
            toggleSwitch.classList.remove('active');
        }
    }

    updateToggleUI(controlId, isOn) {
        const toggleSwitch = document.querySelector(`.toggle-switch[data-id="${controlId}"]`);
        const indicator = document.querySelector(`.status-indicator[data-id="${controlId}"]`);
        const statusText = document.querySelector(`.status-text[data-id="${controlId}"]`);

        if (isOn) {
            toggleSwitch.classList.add('active');
            indicator.className = 'status-indicator on';
            statusText.textContent = 'On';
        } else {
            toggleSwitch.classList.remove('active');
            indicator.className = 'status-indicator off';
            statusText.textContent = 'Off';
        }
    }

    startStatusPolling(control) {
        // Initial status check
        this.updateToggleStatus(control);

        // Poll every 30 seconds
        const interval = setInterval(() => {
            this.updateToggleStatus(control);
        }, 30000);

        this.statusPolling.set(control.id, interval);
    }

    parseHeaders(headersString) {
        if (!headersString || headersString.trim() === '') {
            return {};
        }

        try {
            return JSON.parse(headersString);
        } catch (error) {
            console.error('Error parsing headers:', error);
            return {};
        }
    }

    showFeedback(message, type = 'info') {
        const feedback = document.createElement('div');
        feedback.className = `feedback ${type}`;
        feedback.textContent = message;
        
        document.body.appendChild(feedback);

        // Remove after 4 seconds
        setTimeout(() => {
            if (feedback.parentNode) {
                feedback.parentNode.removeChild(feedback);
            }
        }, 4000);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Enhanced API call with detailed response capture via server proxy
    async makeApiCallWithDetails(control) {
        const requestInfo = {
            url: control.apiUrl,
            method: control.method,
            headers: this.parseHeaders(control.headers),
            body: control.body && ['POST', 'PUT'].includes(control.method) ? control.body : null
        };

        // Call our server-side proxy instead of the target API directly
        const proxyPayload = {
            url: requestInfo.url,
            method: requestInfo.method,
            headers: requestInfo.headers,
            body: requestInfo.body
        };

        try {
            const proxyResponse = await fetch('/api/proxy', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(proxyPayload)
            });

            if (proxyResponse.ok) {
                // Server successfully made the API call
                const proxyData = await proxyResponse.json();
                
                // Create a response-like object for compatibility
                const mockResponse = {
                    ok: proxyData.ok,
                    status: proxyData.status,
                    statusText: proxyData.statusText,
                    headers: new Map(Object.entries(proxyData.headers || {})),
                    json: async () => proxyData.body,
                    text: async () => typeof proxyData.body === 'string' ? proxyData.body : JSON.stringify(proxyData.body)
                };

                return { response: mockResponse, requestInfo };
            } else {
                // Server error (network issues, etc.)
                const errorData = await proxyResponse.json();
                const error = new Error(errorData.message || 'Proxy request failed');
                error.name = errorData.type || 'ProxyError';
                error.code = errorData.code;
                return { error, requestInfo };
            }
        } catch (error) {
            // Network error reaching our own server
            error.message = 'Failed to reach API proxy server: ' + error.message;
            return { error, requestInfo };
        }
    }

    // Response modal management
    bindResponseModalEvents() {
        // Tab switching
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tabName = e.target.dataset.tab;
                this.switchResponseTab(tabName);
            });
        });

        // Close modal when clicking outside
        this.responseModal.addEventListener('click', (e) => {
            if (e.target === this.responseModal) {
                this.closeResponseModal();
            }
        });
    }

    switchResponseTab(tabName) {
        // Remove active class from all tabs and content
        document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));

        // Add active class to selected tab and content
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
        document.getElementById(`${tabName}-tab`).classList.add('active');
    }

    async showResponseModal(control, { response, error, requestInfo }) {
        this.responseTitle.textContent = `${control.label} - API Response`;

        // Populate request tab
        this.requestUrl.textContent = requestInfo.url;
        this.requestMethod.textContent = requestInfo.method;
        this.requestHeaders.textContent = JSON.stringify(requestInfo.headers, null, 2);
        this.requestBody.textContent = requestInfo.body || '(no body)';

        if (error) {
            // Handle network/CORS errors
            this.displayError(error);
        } else {
            // Handle successful response (even if HTTP error status)
            await this.displayResponse(response);
        }

        // Show modal
        this.responseModal.style.display = 'block';
        this.switchResponseTab('response'); // Default to response tab
    }

    async displayResponse(response) {
        // Set status
        this.statusBadge.textContent = response.status;
        this.statusText.textContent = response.statusText || 'Unknown';
        
        if (response.ok) {
            this.statusBadge.className = 'status-badge success';
        } else {
            this.statusBadge.className = 'status-badge error';
        }

        // Get response headers
        const headers = {};
        for (const [key, value] of response.headers.entries()) {
            headers[key] = value;
        }
        this.responseHeaders.textContent = JSON.stringify(headers, null, 2);

        // Get response body
        try {
            const contentType = response.headers.get('content-type') || '';
            let responseText;

            if (contentType.includes('application/json')) {
                const json = await response.json();
                responseText = JSON.stringify(json, null, 2);
                this.responseBody.innerHTML = this.syntaxHighlight(responseText);
            } else {
                responseText = await response.text();
                this.responseBody.textContent = responseText;
            }
        } catch (err) {
            this.responseBody.textContent = 'Error reading response body: ' + err.message;
        }
    }

    displayError(error) {
        // Set error status
        this.statusBadge.textContent = 'ERR';
        this.statusBadge.className = 'status-badge error';
        this.statusText.textContent = 'Network Error';

        // Clear headers
        this.responseHeaders.textContent = 'N/A - Request failed';

        // Create error display
        let errorHtml = '<div class="error-details">';
        
        if (error.name === 'TypeError' && error.message.includes('fetch')) {
            errorHtml += '<div class="error-type">CORS / Network Error</div>';
            errorHtml += '<div class="error-message">The request was blocked by CORS policy or failed to reach the server.</div>';
            errorHtml += '<div class="error-suggestions">';
            errorHtml += '<h4>Possible solutions:</h4>';
            errorHtml += '<ul>';
            errorHtml += '<li>Check if the API server supports CORS for your domain</li>';
            errorHtml += '<li>Verify the URL is correct and the server is running</li>';
            errorHtml += '<li>Try accessing the API from the same domain</li>';
            errorHtml += '<li>Use a CORS proxy service for testing</li>';
            errorHtml += '<li>Configure your API server to allow cross-origin requests</li>';
            errorHtml += '</ul>';
            errorHtml += '</div>';
        } else {
            errorHtml += '<div class="error-type">' + error.name + '</div>';
            errorHtml += '<div class="error-message">' + error.message + '</div>';
        }
        
        errorHtml += '</div>';
        this.responseBody.innerHTML = errorHtml;
    }

    syntaxHighlight(json) {
        json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
            let cls = 'json-number';
            if (/^"/.test(match)) {
                if (/:$/.test(match)) {
                    cls = 'json-key';
                } else {
                    cls = 'json-string';
                }
            } else if (/true|false/.test(match)) {
                cls = 'json-boolean';
            } else if (/null/.test(match)) {
                cls = 'json-null';
            }
            return '<span class="' + cls + '">' + match + '</span>';
        });
    }

    closeResponseModal() {
        this.responseModal.style.display = 'none';
    }

    copyResponse() {
        const activeTab = document.querySelector('.tab-content.active');
        const textToCopy = activeTab.textContent;
        
        navigator.clipboard.writeText(textToCopy).then(() => {
            this.showFeedback('Response copied to clipboard', 'success');
        }).catch(() => {
            this.showFeedback('Failed to copy to clipboard', 'error');
        });
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new APIMenuApp();
});

// Global functions for modals (called from HTML)
window.closeModal = () => {
    if (window.app) {
        window.app.closeModal();
    }
};

window.closeResponseModal = () => {
    if (window.app) {
        window.app.closeResponseModal();
    }
};

window.copyResponse = () => {
    if (window.app) {
        window.app.copyResponse();
    }
};