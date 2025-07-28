// Configuration management for API Menu
class ConfigManager {
    constructor() {
        this.storageKey = 'apiMenuConfig';
        this.defaultConfig = {
            controls: [],
            version: '1.0.0'
        };
    }

    // Load configuration from localStorage
    loadConfig() {
        try {
            const stored = localStorage.getItem(this.storageKey);
            if (stored) {
                const config = JSON.parse(stored);
                return { ...this.defaultConfig, ...config };
            }
        } catch (error) {
            console.error('Error loading config:', error);
        }
        return this.defaultConfig;
    }

    // Save configuration to localStorage
    saveConfig(config) {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(config));
            return true;
        } catch (error) {
            console.error('Error saving config:', error);
            return false;
        }
    }

    // Add a new control to configuration
    addControl(control) {
        const config = this.loadConfig();
        control.id = this.generateId();
        config.controls.push(control);
        this.saveConfig(config);
        return control.id;
    }

    // Update an existing control
    updateControl(id, updates) {
        const config = this.loadConfig();
        const index = config.controls.findIndex(c => c.id === id);
        if (index !== -1) {
            config.controls[index] = { ...config.controls[index], ...updates };
            this.saveConfig(config);
            return true;
        }
        return false;
    }

    // Delete a control
    deleteControl(id) {
        const config = this.loadConfig();
        const index = config.controls.findIndex(c => c.id === id);
        if (index !== -1) {
            config.controls.splice(index, 1);
            this.saveConfig(config);
            return true;
        }
        return false;
    }

    // Get all controls
    getControls() {
        return this.loadConfig().controls;
    }

    // Get a specific control by ID
    getControl(id) {
        const config = this.loadConfig();
        return config.controls.find(c => c.id === id);
    }

    // Export configuration as JSON
    exportConfig() {
        const config = this.loadConfig();
        const blob = new Blob([JSON.stringify(config, null, 2)], {
            type: 'application/json'
        });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `api-menu-config-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // Import configuration from JSON file
    async importConfig(file) {
        try {
            const text = await file.text();
            const config = JSON.parse(text);
            
            // Validate basic structure
            if (!config.controls || !Array.isArray(config.controls)) {
                throw new Error('Invalid configuration format');
            }

            // Regenerate IDs to avoid conflicts
            config.controls.forEach(control => {
                control.id = this.generateId();
            });

            this.saveConfig(config);
            return true;
        } catch (error) {
            console.error('Error importing config:', error);
            throw error;
        }
    }

    // Generate unique ID
    generateId() {
        return 'ctrl_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }

    // Clear all configuration
    clearConfig() {
        localStorage.removeItem(this.storageKey);
    }

    // Validate control configuration
    validateControl(control) {
        const errors = [];

        if (!control.label || control.label.trim() === '') {
            errors.push('Label is required');
        }

        if (!control.apiUrl || control.apiUrl.trim() === '') {
            errors.push('API URL is required');
        } else {
            try {
                new URL(control.apiUrl);
            } catch {
                errors.push('Invalid API URL format');
            }
        }

        if (!control.method || !['GET', 'POST', 'PUT', 'DELETE'].includes(control.method)) {
            errors.push('Valid HTTP method is required');
        }

        if (control.type === 'toggle' && control.statusUrl) {
            try {
                new URL(control.statusUrl);
            } catch {
                errors.push('Invalid status URL format');
            }
        }

        if (control.headers) {
            try {
                JSON.parse(control.headers);
            } catch {
                errors.push('Headers must be valid JSON');
            }
        }

        if (control.body) {
            try {
                JSON.parse(control.body);
            } catch {
                errors.push('Request body must be valid JSON');
            }
        }

        return errors;
    }
}

// Export for use in other files
window.ConfigManager = ConfigManager;