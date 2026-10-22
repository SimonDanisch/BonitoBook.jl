// Build-only entry, copied beside the pinned Monaco ESM sources by build_monaco.
// Use Monaco's tokenizers and themes without its browser/editor services.
import {Event} from './base/common/event.js';
import {Token, TokenizationRegistry} from './editor/common/languages.js';
import {ModesRegistry} from './editor/common/languages/modesRegistry.js';
import {LanguageService} from './editor/common/services/languageService.js';
import {TokenTheme, generateTokensCSSForColorMap} from './editor/common/languages/supports/tokenization.js';
import {TokenMetadata} from './editor/common/encodedTokenAttributes.js';
import {MonarchTokenizer} from './editor/standalone/common/monarch/monarchLexer.js';
import {compile} from './editor/standalone/common/monarch/monarchCompile.js';
import {vs} from './editor/standalone/common/themes.js';
import {createTokenizationSupport} from './language/json/tokenization.js';

const jobs = new Map();
const tokenTheme = TokenTheme.createFromRawTokenTheme(vs.rules, []);
const theme = {getColorTheme: () => ({tokenTheme})};
// Immutable equivalent of Monaco's default tokenization configuration.
const configuration = {
    getValue(key) {
        if (key !== 'editor.maxTokenizationLineLength') throw new Error(`Unknown tokenizer setting: ${key}`);
        return 20000;
    },
    onDidChangeConfiguration: Event.None,
};
let languages;

export function registerLanguage(definition) {
    ModesRegistry.registerLanguage(definition);
    TokenizationRegistry.registerFactory(definition.id, {
        get tokenizationSupport() {
            return definition.loader().then(({language}) =>
                new MonarchTokenizer(languages, theme, definition.id,
                    compile(definition.id, language), configuration));
        },
    });
}

function escaped(text, startColumn) {
    let result = '', column = startColumn;
    for (const char of text) {
        if (char === '\t') {
            const width = 4 - column % 4;
            result += '&nbsp;'.repeat(width); column += width;
        } else {
            result += char === '&' ? '&amp;' : char === '<' ? '&lt;' : char === '>' ? '&gt;' :
                char === ' ' ? '&nbsp;' : char;
            column += char.length;
        }
    }
    return [result, column];
}

function coloredLine(text, tokens, language) {
    let html = '', column = 0, previous = null, contents = '';
    const id = languages.languageIdCodec.encodeLanguageId(language);
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        const end = i + 1 < tokens.length ? tokens[i + 1].offset : text.length;
        const [content, nextColumn] = escaped(text.slice(token.offset, end), column);
        column = nextColumn;
        const classes = TokenMetadata.getClassNameFromMetadata(tokenTheme.match(id, token.type));
        // Monaco's encoded tokenizer also merges adjacent tokens with the
        // same appearance. Keep that DOM bound when using classic scopes.
        if (classes !== previous && previous !== null) {
            html += `<span class="${previous}">${contents}</span>`;
            contents = '';
        }
        previous = classes;
        contents += content;
    }
    if (previous !== null) html += `<span class="${previous}">${contents}</span>`;
    return html;
}

async function batch(id) {
    const job = jobs.get(id);
    if (!job) return;
    const rows = [];
    const until = performance.now() + 3;
    while (job.index < job.lines.length && rows.length < 64) {
        const line = job.lines[job.index].replace(/\r$/, '');
        let result = job.tokenizer.tokenize(line, true, job.state);
        // HTML and other embedded languages can discover a new tokenizer on
        // this line. Load it and retry from the original state before advancing.
        if (job.tokenizer.getLoadStatus) {
            let status = job.tokenizer.getLoadStatus();
            while (!status.loaded) {
                await status.promise;
                if (!jobs.has(id)) return;
                result = job.tokenizer.tokenize(line, true, job.state);
                status = job.tokenizer.getLoadStatus();
            }
        }
        rows.push([job.index++, coloredLine(line, result.tokens, job.language)]);
        job.state = result.endState;
        if (performance.now() >= until) break;
    }
    const done = job.index === job.lines.length;
    if (done) jobs.delete(id);
    self.postMessage({id, rows, done});
}

export function start() {
    ModesRegistry.registerLanguage({id:'json',
        extensions:['.json', '.bowerrc', '.jshintrc', '.jscsrc', '.eslintrc', '.babelrc', '.har'],
        aliases:['JSON', 'json'], mimetypes:['application/json']});
    languages = new LanguageService();
    const json = createTokenizationSupport(true);
    TokenizationRegistry.register('json', {
        getInitialState: () => json.getInitialState(),
        tokenize(line, hasEOL, state) {
            const result = json.tokenize(line, state);
            return {endState:result.endState,
                tokens:result.tokens.map(t => new Token(t.startIndex, t.scopes, 'json'))};
        },
    });
    const css = generateTokensCSSForColorMap(tokenTheme.getColorMap())
        .replace(/(^|\n)(\.mtk)/g, '$1.bt-code $2');
    self.postMessage({ready:true, css, languages:ModesRegistry.getLanguages().map(({loader, ...meta}) => meta)});
    self.onmessage = async ({data}) => {
        const {id, type} = data;
        try {
            if (type === 'cancel') { jobs.delete(id); return; }
            if (type === 'start') {
                const job = {};
                jobs.set(id, job);
                const tokenizer = await TokenizationRegistry.getOrCreate(data.language);
                if (jobs.get(id) !== job) return;
                if (!tokenizer) throw new Error(`No tokenizer for language: ${data.language}`);
                Object.assign(job, {tokenizer, language:data.language, lines:data.text.split('\n'),
                    index:0, state:tokenizer.getInitialState()});
            } else if (type !== 'next') throw new Error(`Unknown tokenizer request: ${type}`);
            await batch(id);
        } catch (error) {
            jobs.delete(id);
            self.postMessage({id, error:String(error.stack || error)});
        }
    };
}
