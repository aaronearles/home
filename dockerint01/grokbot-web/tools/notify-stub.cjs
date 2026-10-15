// Page-side stub for notify-test: records notifications instead of showing them
window.__shown = [];
window.Notification = class {
  static permission = 'granted';
  static requestPermission() { return Promise.resolve('granted'); }
  constructor(title, options) { this.title = title; this.options = options; this.closed = false; window.__shown.push(this); }
  close() { this.closed = true; }
};
