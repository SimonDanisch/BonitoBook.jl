import {workerSource} from './vendor/code_tokenizer.js';

class TokenWorker {
    constructor() {
        this.pending = new Map();
        this.nextId = 0;
        const url = URL.createObjectURL(new Blob([workerSource], {type:'text/javascript'}));
        this.worker = new Worker(url, {type:'module', name:'transcript-tokenizer'});
        this.ready = new Promise((resolve, reject) => {
            this.worker.onerror = event => {
                const error = new Error(event.message);
                this.failure = error;
                reject(error);
                for (const job of this.pending.values()) job.reject(error);
                this.pending.clear();
                this.worker.terminate();
                URL.revokeObjectURL(url);
            };
            this.worker.onmessage = event => {
                if (event.data.ready) {
                    URL.revokeObjectURL(url);
                    const style = document.createElement('style');
                    style.textContent = event.data.css;
                    document.head.appendChild(style);
                    resolve(event.data.languages);
                } else this.receive(event.data);
            };
        });
    }
    async receive({id, rows, done, error}) {
        const job = this.pending.get(id);
        if (!job) return;
        if (error) { this.pending.delete(id); job.reject(new Error(error)); return; }
        try {
            let until = performance.now() + 3;
            for (const [index, html] of rows) {
                if (job.onLine(index, html) === false) {
                    this.worker.postMessage({type:'cancel', id});
                    this.pending.delete(id); job.resolve(); return;
                }
                if (performance.now() >= until) {
                    await new Promise(resolve => setTimeout(resolve, 0));
                    until = performance.now() + 3;
                }
            }
            if (done) { this.pending.delete(id); job.resolve(); }
            else this.worker.postMessage({type:'next', id});
        } catch (error) {
            this.worker.postMessage({type:'cancel', id});
            this.pending.delete(id); job.reject(error);
        }
    }
    async colorize(text, language, onLine) {
        const languages = await this.ready;
        if (this.failure) throw this.failure;
        const registered = languages.find(l => l.id === language ||
            (l.aliases || []).some(alias => alias.toLowerCase() === language.toLowerCase()));
        if (!registered) return; // Monaco also leaves unknown languages plain.
        language = registered.id;
        return new Promise((resolve, reject) => {
            const id = ++this.nextId;
            this.pending.set(id, {onLine, resolve, reject});
            this.worker.postMessage({type:'start', id, text, language});
        });
    }
}

let client;
function tokenizer() { return client || (client = new TokenWorker()); }

export function colorize_lines(text, language, onLine) {
    return tokenizer().colorize(text, language, onLine);
}

export async function language_for_path(path) {
    const name = path.split(/[\\/]/).pop().toLowerCase();
    for (const lang of await tokenizer().ready) {
        if ((lang.filenames || []).some(f => f.toLowerCase() === name)) return lang.id;
        if ((lang.extensions || []).some(e => name.endsWith(e.toLowerCase()))) return lang.id;
    }
    return 'plaintext';
}
