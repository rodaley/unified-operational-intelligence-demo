const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, BorderStyle, ShadingType, LevelFormat,
  convertInchesToTwip, PageBreak, Footer, PageNumber, TableOfContents,
} = require('docx');

// Redacted frames: identical portal captures with the signed-in account chip,
// directory name, subscription name and subscription ID painted out, so the
// document can be shared outside the tenant. Regenerate with redact.ps1.
const SHOTS = path.join(__dirname, 'shots-redacted');
const OUT = process.argv[2] || path.join(__dirname, 'UOI-Azure-Portal-Demo-Walkthrough.docx');

// ---------- palette ----------
const AZ_BLUE = '0F6CBD';
const AZ_DARK = '13324B';
const GREY = '505050';
const RULE = 'D1D1D1';
const TINT = 'EFF6FC';
const WARN = 'FFF4CE';
const GOOD = 'E7F6EC';

// ---------- image sizing ----------
const CONTENT_IN = 6.5; // letter, 1in margins

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20), data: b };
}

function figure(fileName, caption) {
  const full = path.join(SHOTS, fileName);
  const { w, h, data } = pngSize(full);
  const width = Math.round(CONTENT_IN * 96);
  const height = Math.round((width * h) / w);
  const out = [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 160, after: 60 },
      children: [
        new ImageRun({
          type: 'png',
          data,
          transformation: { width, height },
          altText: {
            title: caption,
            description: caption,
            name: fileName,
          },
        }),
      ],
    }),
  ];
  if (caption) {
    out.push(
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 240 },
        children: [
          new TextRun({ text: caption, italics: true, size: 17, color: GREY, font: 'Arial' }),
        ],
      })
    );
  }
  return out;
}

function figureIfExists(fileName, caption) {
  if (!fs.existsSync(path.join(SHOTS, fileName))) {
    console.log(`WARNING: missing screenshot ${fileName} - figure omitted`);
    return [];
  }
  return figure(fileName, caption);
}

// ---------- text helpers ----------
const P = (text, opts = {}) =>
  new Paragraph({
    spacing: { after: opts.after ?? 140, line: 276 },
    children: [new TextRun({ text, size: opts.size ?? 21, font: 'Arial', color: opts.color, bold: opts.bold, italics: opts.italics })],
  });

const Rich = (runs, opts = {}) =>
  new Paragraph({
    spacing: { after: opts.after ?? 140, line: 276 },
    alignment: opts.align,
    children: runs.map((r) =>
      typeof r === 'string'
        ? new TextRun({ text: r, size: 21, font: 'Arial' })
        : new TextRun({ size: 21, font: 'Arial', ...r })
    ),
  });

const H1 = (text) =>
  new Paragraph({
    heading: HeadingLevel.HEADING_1,
    outlineLevel: 0,
    spacing: { before: 360, after: 160 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 10, color: AZ_BLUE, space: 6 } },
    children: [new TextRun({ text, size: 30, bold: true, color: AZ_DARK, font: 'Arial' })],
  });

const H2 = (text) =>
  new Paragraph({
    heading: HeadingLevel.HEADING_2,
    outlineLevel: 1,
    spacing: { before: 280, after: 120 },
    children: [new TextRun({ text, size: 25, bold: true, color: AZ_BLUE, font: 'Arial' })],
  });

const H3 = (text) =>
  new Paragraph({
    heading: HeadingLevel.HEADING_3,
    outlineLevel: 2,
    spacing: { before: 200, after: 100 },
    children: [new TextRun({ text, size: 22, bold: true, color: AZ_DARK, font: 'Arial' })],
  });

const Step = (text, runs) =>
  new Paragraph({
    numbering: { reference: 'steps', level: 0 },
    spacing: { after: 120, line: 276 },
    children: runs
      ? runs.map((r) => (typeof r === 'string' ? new TextRun({ text: r, size: 21, font: 'Arial' }) : new TextRun({ size: 21, font: 'Arial', ...r })))
      : [new TextRun({ text, size: 21, font: 'Arial' })],
  });

const Bullet = (text, runs) =>
  new Paragraph({
    numbering: { reference: 'bullets', level: 0 },
    spacing: { after: 90, line: 276 },
    children: runs
      ? runs.map((r) => (typeof r === 'string' ? new TextRun({ text: r, size: 21, font: 'Arial' }) : new TextRun({ size: 21, font: 'Arial', ...r })))
      : [new TextRun({ text, size: 21, font: 'Arial' })],
  });

// Callout box
function callout(label, lines, fill) {
  const kids = [
    new Paragraph({
      spacing: { after: 60 },
      children: [new TextRun({ text: label, bold: true, size: 20, font: 'Arial', color: AZ_DARK })],
    }),
    ...lines.map((l) =>
      new Paragraph({
        spacing: { after: 40, line: 264 },
        children: (Array.isArray(l) ? l : [l]).map((r) =>
          typeof r === 'string'
            ? new TextRun({ text: r, size: 20, font: 'Arial' })
            : new TextRun({ size: 20, font: 'Arial', ...r })
        ),
      })
    ),
  ];
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: [9360],
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: fill },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: fill },
      left: { style: BorderStyle.SINGLE, size: 18, color: AZ_BLUE },
      right: { style: BorderStyle.SINGLE, size: 2, color: fill },
      insideHorizontal: { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
      insideVertical: { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 9360, type: WidthType.DXA },
            shading: { type: ShadingType.CLEAR, fill, color: 'auto' },
            margins: { top: 140, bottom: 140, left: 180, right: 180 },
            children: kids,
          }),
        ],
      }),
    ],
  });
}

// Script line ("say this")
const SayThis = (text) =>
  callout('SAY THIS', [[{ text: '\u201C' + text + '\u201D', italics: true }]], TINT);

// code block
const Code = (lines) =>
  new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: [9360],
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      left: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      right: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      insideHorizontal: { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
      insideVertical: { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 9360, type: WidthType.DXA },
            shading: { type: ShadingType.CLEAR, fill: 'F5F5F5', color: 'auto' },
            margins: { top: 120, bottom: 120, left: 160, right: 160 },
            children: lines.map(
              (l) =>
                new Paragraph({
                  spacing: { after: 20, line: 240 },
                  children: [new TextRun({ text: l, size: 18, font: 'Consolas' })],
                })
            ),
          }),
        ],
      }),
    ],
  });

// data table
function dataTable(headers, rows, widths) {
  const total = 9360;
  const cols = widths || headers.map(() => Math.floor(total / headers.length));
  const mk = (text, bold, fill) =>
    new TableCell({
      width: { size: cols[0], type: WidthType.DXA },
      shading: fill ? { type: ShadingType.CLEAR, fill, color: 'auto' } : undefined,
      margins: { top: 90, bottom: 90, left: 120, right: 120 },
      children: [
        new Paragraph({
          spacing: { after: 0, line: 260 },
          children: [new TextRun({ text, bold, size: 19, font: 'Arial', color: bold ? 'FFFFFF' : undefined })],
        }),
      ],
    });

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map(
      (h, i) =>
        new TableCell({
          width: { size: cols[i], type: WidthType.DXA },
          shading: { type: ShadingType.CLEAR, fill: AZ_BLUE, color: 'auto' },
          margins: { top: 90, bottom: 90, left: 120, right: 120 },
          children: [
            new Paragraph({
              spacing: { after: 0, line: 260 },
              children: [new TextRun({ text: h, bold: true, size: 19, font: 'Arial', color: 'FFFFFF' })],
            }),
          ],
        })
    ),
  });

  const bodyRows = rows.map(
    (r, ri) =>
      new TableRow({
        children: r.map(
          (c, i) =>
            new TableCell({
              width: { size: cols[i], type: WidthType.DXA },
              shading: { type: ShadingType.CLEAR, fill: ri % 2 ? 'F7F9FB' : 'FFFFFF', color: 'auto' },
              margins: { top: 90, bottom: 90, left: 120, right: 120 },
              children: [
                new Paragraph({
                  spacing: { after: 0, line: 260 },
                  children: [new TextRun({ text: c, size: 19, font: 'Arial' })],
                }),
              ],
            })
        ),
      })
  );

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: cols,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      left: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      right: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      insideHorizontal: { style: BorderStyle.SINGLE, size: 2, color: RULE },
      insideVertical: { style: BorderStyle.SINGLE, size: 2, color: RULE },
    },
    rows: [headerRow, ...bodyRows],
  });
}

const Spacer = (after = 200) => new Paragraph({ spacing: { after }, children: [] });

// =====================================================================
// CONTENT
// =====================================================================
const children = [];

// ---- Title page ----
children.push(
  new Paragraph({ spacing: { before: 2200, after: 0 }, children: [] }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 80 },
    children: [new TextRun({ text: 'Unified Operational Intelligence', size: 56, bold: true, color: AZ_DARK, font: 'Arial' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 240 },
    children: [new TextRun({ text: 'Azure Portal Demonstration \u2014 Step-by-Step Walkthrough', size: 28, color: AZ_BLUE, font: 'Arial' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 400 },
    children: [
      new TextRun({ text: 'Every screenshot in this document is a live capture of the Azure Portal', size: 20, italics: true, color: GREY, font: 'Arial' }),
      new TextRun({ text: '', break: 1 }),
      new TextRun({ text: 'rendering the deployed estate in resource group rg-uoi-iaas.', size: 20, italics: true, color: GREY, font: 'Arial' }),
    ],
  }),
  callout(
    'MANDATORY LABELLING \u2014 STATE THIS UP FRONT',
    [
      [{ text: 'Synthetic Demo Data. ', bold: true }, { text: 'The business, incident and financial layer in this demonstration is generated. Every generated record carries an ' }, { text: 'IsSynthetic', font: 'Consolas', size: 19 }, { text: ' flag in the data itself.' }],
      [{ text: 'Illustrative Sample Data, not a customer estimate. ', bold: true }, { text: 'All revenue, cost and tool-spend figures are illustrative and must not be presented as a customer-specific projection.' }],
      [{ text: 'No autonomous remediation. ', bold: true }, { text: 'Nothing in this demonstration changes a system without an explicit human approval decision.' }],
    ],
    WARN
  ),
  new Paragraph({ children: [new PageBreak()] })
);

// ---- TOC ----
children.push(
  H1('Contents'),
  new TableOfContents('Contents', { hyperlink: true, headingStyleRange: '1-2' }),
  new Paragraph({ children: [new PageBreak()] })
);

// ---- Section: how to use ----
children.push(
  H1('How to use this document'),
  P('This is a presenter walkthrough. Each step tells you exactly where to click in the Azure Portal, shows you what you should see when you get there, and gives you the line to say.'),
  P('The demonstration runs for roughly 30 minutes with discussion. It has five surfaces, in this order:'),
  Spacer(120),
  dataTable(
    ['#', 'Surface', 'What it proves', 'Time'],
    [
      ['1', 'Azure Dashboard', 'This is native Azure Monitor \u2014 no custom application', '2 min'],
      ['2', 'Azure Workbook (5 tabs)', 'Correlation, business impact, spend, evidence', '10\u201312 min'],
      ['3', 'VM Insights \u2192 Alerts \u2192 Logs', 'The data is real and can be interrogated live', '5 min'],
      ['4', 'Observability agent', 'The AI layer is native too \u2014 nothing deployed', '4 min'],
      ['5', 'Automation runbook', 'A human approves. Approvals and refusals are audited', '5 min'],
    ],
    [700, 2500, 4660, 1500]
  ),
  Spacer(),
  callout(
    'THE ONE SENTENCE THAT MATTERS',
    [[{ text: '150 related alerts correlated into 1 actionable incident.', bold: true, size: 24 }]],
    GOOD
  ),
  Spacer(120),
  Rich([
    { text: 'Say it exactly that way. Do ', bold: false },
    { text: 'not', bold: true },
    { text: ' say \u201Cfalse positives\u201D. Each of the 150 alerts was a genuine signal from a component that was genuinely affected. The value is not that the alerts were wrong \u2014 it is that a responder should be handed ' },
    { text: 'one incident to work', bold: true },
    { text: ' rather than 150 notifications to triage individually.' },
  ])
);

// ---- Section: before you start ----
children.push(
  H1('Before the demonstration'),
  H2('Start the estate at least 20 minutes early'),
  P('Telemetry takes roughly ten minutes to appear after the virtual machines start. Zero rows immediately after a successful start is latency, not failure.'),
  Code([
    '# Start the six virtual machines',
    'az vm start --ids $(az vm list -g rg-uoi-iaas `',
    '    --subscription <subscription-id> --query "[].id" -o tsv)',
  ]),
  Spacer(160),
  H2('Seed once, on the day you present'),
  P('The synthetic business layer is timestamped at the moment it is seeded and spans roughly a 45-minute window. The workbook defaults to a 24-hour range, so data seeded yesterday will have aged out and the incident, impact and spend tabs will render empty.'),
  Rich([
    { text: 'The seeder runs ' },
    { text: 'on an estate virtual machine', bold: true },
    { text: ' and authenticates through its managed identity, so there is no secret anywhere and nothing to configure locally. Invoke it remotely:' },
  ]),
  Code([
    '$dce = \'<your-dce-endpoint>\'        # see the Environment table',
    '$dcr = \'<your-dcr-immutable-id>\'',
    '# upload seed-estate.py to the VM, then:',
    'az vm run-command invoke -g rg-uoi-iaas -n vm-web-01 `',
    '  --command-id RunShellScript --scripts `',
    '  "python3 /tmp/seed.py --endpoint $dce --rule-id $dcr --anchor now"',
  ]),
  Spacer(120),
  P('Expect it to report 150 alert records, 360 service-health records and 30 cost records, all labelled IsSynthetic=true.'),
  callout('SEED ONCE \u2014 NOT TWICE', [
    [{ text: 'The Logs Ingestion API has no upsert, so seeding twice writes 300 rows rather than 150.', bold: true }],
    [{ text: 'The ' }, { text: 'workbook', bold: true }, { text: ' is immune: every seeded query scopes to the newest ingestion batch and de-duplicates on AlertId, so the headline still reads 150. This was verified on a double-seeded workspace.' }],
    [{ text: 'The ' }, { text: 'Observability agent in Step 11 is not immune', bold: true }, { text: ' \u2014 it counts rows unless told otherwise, and will answer 300. If you must re-seed, use the exact prompt given in Step 11.' }],
  ], WARN),
  H2('Verify every tile before you go on stage'),
  P('ARM validates the workbook JSON but never the KQL inside it. This script executes all 17 embedded workbook queries against the live workspace and is the only check that catches a broken tile before an audience does.'),
  Code(['.\\infra-iaas\\scripts\\validate-workbook.ps1 -SubscriptionId <subscription-id>']),
  Spacer(120),
  P('Expect "17/17 ok" and exit code 0.'),
  H2('Cost'),
  Rich([
    { text: 'The estate runs six ' },
    { text: 'Standard_D2ls_v7', font: 'Consolas', size: 19 },
    { text: ' virtual machines at ' },
    { text: '$17.28 per day', bold: true },
    { text: ' if left running \u2014 $0.12 per hour each, verified against the Azure retail price API \u2014 or roughly ' },
    { text: '$548 per month', bold: true },
    { text: ' at 24\u00d77 once disks and Log Analytics ingestion are included. The estate is therefore left deallocated between demonstrations, which stops compute billing while preserving the disks, the workspace and every row already ingested. A daily auto-shutdown at 23:00 UTC is configured on every machine as a backstop, so an estate started and then forgotten bills for one day rather than a month. Start the machines before you present and allow five to ten minutes for the monitoring agents to reconnect.' },
  ]),
  Code([
    '# start before presenting',
    'az vm start --ids $(az vm list -g rg-uoi-iaas `',
    '    --subscription <subscription-id> --query "[].id" -o tsv)',
    '',
    '# stop afterwards',
    'az vm deallocate --ids $(az vm list -g rg-uoi-iaas `',
    '    --subscription <subscription-id> --query "[].id" -o tsv) --no-wait',
  ]),
  new Paragraph({ children: [new PageBreak()] })
);

// ---- Section: real vs synthetic ----
children.push(
  H1('What is real and what is synthetic'),
  P('State this out loud at the start. It is a credibility asset, not a disclaimer to hide. An executive audience trusts a presenter who draws the line before being asked to.'),
  Spacer(120),
  dataTable(
    ['Layer', 'Status'],
    [
      ['The six virtual machines', 'REAL \u2014 running Ubuntu in rg-uoi-iaas, East US 2'],
      ['CPU, memory, disk and network telemetry', 'REAL \u2014 collected by Azure Monitor Agent into InsightsMetrics'],
      ['Syslog', 'REAL \u2014 collected by Azure Monitor Agent'],
      ['Heartbeat and agent health', 'REAL'],
      ['Alert rules, fired alerts, action group', 'REAL Azure Monitor resources. The correlated-incident alert has genuinely fired.'],
      ['Workbook, dashboard, Automation runbook', 'REAL Azure resources'],
      ['Business services, incidents, revenue, tool spend', 'SYNTHETIC \u2014 generated, labelled IsSynthetic = true, ingested through a real Data Collection Rule'],
    ],
    [3400, 5960]
  ),
  Spacer(),
  H2('Known gap \u2014 state it plainly'),
  Rich([
    { text: 'The VM Insights ' },
    { text: 'Map', bold: true },
    { text: ' tab is not available in this estate. The Dependency Agent does not support the Ubuntu builds deployed here. VM Insights ' },
    { text: 'Performance', bold: true },
    { text: ' works from the Azure Monitor Agent alone, and service topology is presented in the workbook instead. Say this before someone clicks the tab and finds it empty.' },
  ]),
  Spacer(120),
  H2('Environment'),
  dataTable(
    ['Item', 'Value'],
    [
      ['Subscription', '<your-subscription-id>'],
      ['Resource group', 'rg-uoi-iaas'],
      ['Region', 'East US 2 (eastus2)'],
      ['Log Analytics workspace', 'log-uoi'],
      ['Workbook', 'UOI \u2014 Unified Operational Intelligence'],
      ['Dashboard', 'dash-uoi'],
      ['Automation account', 'aa-uoi'],
    ],
    [3000, 6360]
  ),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 1 - resource group
// =====================================================================
children.push(
  H1('Step 1 \u2014 The estate'),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Resource groups', bold: true }, { text: ' \u2192 ' }, { text: 'rg-uoi-iaas', font: 'Consolas', size: 19 }, { text: '.' }]),
  Step('Leave the resource list on screen while you set the scene.'),
  Spacer(80),
  H2('What you should see'),
  ...figure('01-resource-group.png', 'Figure 1 \u2014 Resource group rg-uoi-iaas. Six virtual machines, the Log Analytics workspace, Data Collection Rules, the Automation account and the alert rules \u2014 all real Azure resources.'),
  SayThis('Everything in this demonstration lives in one resource group. Six virtual machines, a Log Analytics workspace, the Data Collection Rules that get telemetry there, and native Azure Monitor alert rules. There is no custom application anywhere in this picture.'),
  Spacer(160),
  callout('WHY START HERE', [
    'Opening on the resource list answers the "is this a mock-up?" question before it is asked. The audience sees genuine Azure resource types with genuine provisioning states, not a product screenshot.',
  ], TINT),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 2 - dashboard
// =====================================================================
children.push(
  H1('Step 2 \u2014 Dashboard: the opening frame'),
  P('Approximately 2 minutes.'),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Dashboard', bold: true }, { text: ' (from the portal menu, top left).' }]),
  Step(null, [{ text: 'Select ' }, { text: 'dash-uoi', font: 'Consolas', size: 19 }, { text: ' from the dashboard picker.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('02-dashboard.png', 'Figure 2 \u2014 The dash-uoi dashboard. Synthetic-data labelling, the headline correlation figure, and live Azure Monitor charts reading real virtual machine metrics.'),
  SayThis('This is native Azure Monitor. No custom application, no export, no middleware. This is the Azure Portal rendering data that is already in the platform.'),
  Spacer(160),
  callout('PRESENTER NOTE', [
    'This is the "walk in and it is already on screen" view. If you are presenting to an audience that arrives in stages, leave this up. It carries the labelling and the headline number without you having to say anything.',
  ], TINT),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 3 - workbook tab 1
// =====================================================================
children.push(
  H1('Step 3 \u2014 Workbook, Tab 1: Estate health'),
  P('The workbook is the main event \u2014 10 to 12 minutes across its five tabs.'),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Monitor', bold: true }, { text: ' \u2192 ' }, { text: 'Workbooks', bold: true }, { text: '.' }]),
  Step(null, [{ text: 'Open ' }, { text: 'UOI \u2014 Unified Operational Intelligence', bold: true }, { text: '.' }]),
  Step(null, [{ text: 'Confirm the ' }, { text: 'Time range', bold: true }, { text: ' parameter at the top reads ' }, { text: 'Last 24 hours', bold: true }, { text: '. This single parameter re-scopes all 17 query items together.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('03-workbook-estate.png', 'Figure 3 \u2014 Tab 1, Estate health. All six virtual machines listed with their tier and reporting status, under a 24-hour shared time range. Note the synthetic-data labelling carried in the workbook itself.'),
  SayThis('These are real machines emitting real telemetry, collected by the Azure Monitor Agent through a Data Collection Rule. Nothing on this tab is mocked.'),
  Spacer(120),
  P('Scroll down on the same tab to reach the live performance charts.'),
  ...figure('03b-workbook-estate-cpu.png', 'Figure 4 \u2014 Tab 1 continued. Real CPU, memory and network series drawn from InsightsMetrics, the same table VM Insights reads from.'),
  callout('IF A TILE IS BLANK', [
    'Widen the Time range parameter before assuming a fault. The synthetic business layer ages out of a 24-hour window. The estate-health tiles read real telemetry and should never be empty while the virtual machines are running.',
  ], WARN),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 4 - workbook tab 2  (money slide)
// =====================================================================
children.push(
  H1('Step 4 \u2014 Workbook, Tab 2: Incident correlation'),
  callout('THIS IS THE MONEY SLIDE', [
    [{ text: 'Slow down here. Everything before this was setting up the claim; everything after it is evidence for the claim. This tab is the claim.', bold: true }],
  ], GOOD),
  Spacer(160),
  H2('Where to click'),
  Step(null, [{ text: 'In the workbook, select the ' }, { text: 'Incident correlation', bold: true }, { text: ' tab.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('04-workbook-incident.png', 'Figure 5 \u2014 Tab 2, Incident correlation. The headline tile: 150 related alerts, 1 actionable incident, a 99% reduction in items to triage.'),
  Spacer(80),
  dataTable(
    ['Related alerts', 'Actionable incidents', 'Reduction in items to triage'],
    [['150', '1', '99%']],
    [3120, 3120, 3120]
  ),
  Spacer(),
  SayThis('150 related alerts correlated into 1 actionable incident.'),
  Spacer(160),
  H2('The discipline that makes this credible'),
  callout('DO NOT SAY \u201CFALSE POSITIVES\u201D', [
    [{ text: 'These are ' }, { text: 'related alerts', italics: true }, { text: ', not false positives. Each one is a genuine signal from a component that was genuinely affected. The value of correlation is not that the alerts were wrong \u2014 it is that a responder should be handed ' }, { text: 'one incident to work', bold: true }, { text: ' rather than 150 notifications to triage individually.' }],
    [{ text: 'Correlation here indicates a ' }, { text: 'relationship', bold: true }, { text: ' between signals. It does not, by itself, prove causation.' }],
  ], WARN),
  Spacer(160),
  P('Scroll down to walk the audience through the storm as an operator actually experiences it.'),
  ...figure('04b-workbook-incident-detail.png', 'Figure 6 \u2014 Tab 2 continued. Alert arrival over time broken down by tier \u2014 62 web, 54 app, 34 data, totalling the 150 related alerts \u2014 and the earliest Sev1 signal in the incident.'),
  H2('Walking the detail'),
  Bullet(null, [{ text: 'The arrival chart. ', bold: true }, { text: 'This is the storm as it lands \u2014 alerts stacking up across the web, app and data tiers over roughly 45 minutes. This is the experience correlation removes.' }]),
  Bullet(null, [{ text: 'The tier totals. ', bold: true }, { text: '62 web plus 54 app plus 34 data. The arithmetic is visible on screen, which is worth more than the presenter asserting the number.' }]),
  Bullet(null, [{ text: 'The earliest signal. ', bold: true }, { text: 'A Sev1 on vm-sql-01 \u2014 storage latency on the data tier exceeding 400 ms sustained. This is where a responder should look first.' }]),
  Spacer(120),
  SayThis('This is the first related signal in the window. Correlation shows these alerts are related \u2014 it does not by itself prove causation. What it does is tell the responder where to look first, instead of leaving them to work out which of 150 notifications mattered.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 5 - tab 3
// =====================================================================
children.push(
  H1('Step 5 \u2014 Workbook, Tab 3: Business impact'),
  H2('Where to click'),
  Step(null, [{ text: 'Select the ' }, { text: 'Business impact', bold: true }, { text: ' tab.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('05-workbook-impact.png', 'Figure 7 \u2014 Tab 3, Business impact. Service health, peak concurrent degradation and revenue at risk, per business service.'),
  callout('LABEL IT BEFORE ANYONE ASKS', [
    [{ text: 'Illustrative Sample Data, not a customer estimate.', bold: true }],
    'Say this the moment the tab opens. The figures exist to demonstrate that operational signals can be expressed in business terms \u2014 not to assert what an outage would cost this particular customer.',
  ], WARN),
  Spacer(160),
  SayThis('The point of this tab is not the numbers. It is that the same correlated incident can be expressed in the language the business actually uses. These figures are illustrative sample data, not a customer estimate \u2014 in a real engagement the inputs would be yours.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 6 - tab 4
// =====================================================================
children.push(
  H1('Step 6 \u2014 Workbook, Tab 4: Observability spend'),
  H2('Where to click'),
  Step(null, [{ text: 'Select the ' }, { text: 'Observability spend', bold: true }, { text: ' tab.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('06-workbook-spend.png', 'Figure 8 \u2014 Tab 4, Observability spend. Current tool spend by category and the overlap analysis across tooling.'),
  callout('THIS IS A CONSOLIDATION ARGUMENT, NOT A COMPETITIVE TEARDOWN', [
    [{ text: 'Do not frame the customer\u2019s existing investment as a mistake.', bold: true }, { text: ' It solved the problem they had at the time, and saying otherwise insults the people in the room who chose it.' }],
    'The argument is narrower and more defensible: estate-wide correlation is now available natively where the workloads already run, with one less integration boundary to maintain.',
  ], WARN),
  Spacer(160),
  SayThis('Nothing here says the existing tooling was the wrong choice. It solved a real problem. The question on the table is different \u2014 whether estate-wide correlation still needs to live outside the platform the workloads already run on.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 7 - tab 5
// =====================================================================
children.push(
  H1('Step 7 \u2014 Workbook, Tab 5: Response'),
  H2('Where to click'),
  Step(null, [{ text: 'Select the ' }, { text: 'Response', bold: true }, { text: ' tab.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('07-workbook-response.png', 'Figure 9 \u2014 Tab 5, Response. The evidence chain behind the incident and the remediation audit trail.'),
  P('The audit trail will not contain today\u2019s entries until you have run the approval gate in Step 12. That is intentional \u2014 you will come back to this tab at the end of the demonstration and show the entries appear.'),
  Spacer(120),
  SayThis('This is the evidence chain \u2014 what was observed, in what order, and what was proposed as a result. At the bottom is the audit trail. It is empty of today because nobody has approved anything yet. We will come back to it.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 8 - VM insights
// =====================================================================
children.push(
  H1('Step 8 \u2014 Native drill-down: VM Insights'),
  P('Approximately 5 minutes across Steps 8 to 10. This is the part that only works because the solution is genuinely Azure-native. Leave the workbook entirely.'),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Monitor', bold: true }, { text: ' \u2192 ' }, { text: 'Virtual Machines', bold: true }, { text: ' \u2192 ' }, { text: 'Performance', bold: true }, { text: ' tab.' }]),
  Step(null, [{ text: 'Or open ' }, { text: 'vm-web-01', font: 'Consolas', size: 19 }, { text: ' \u2192 ' }, { text: 'Monitoring', bold: true }, { text: ' \u2192 ' }, { text: 'Insights', bold: true }, { text: '.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('08-vm-insights.png', 'Figure 10 \u2014 VM Insights. A standard Azure Monitor experience, unmodified, reading the same telemetry the workbook reads.'),
  SayThis('I have not left the product. This is stock VM Insights, reading the same data the workbook was reading. The workbook is not a separate system with its own copy of the truth \u2014 it is a view over the platform you already have.'),
  Spacer(160),
  callout('REMINDER \u2014 THE MAP TAB', [
    'Do not click Map. The Dependency Agent does not support the Ubuntu builds in this estate. Mention it before someone else finds it: service topology is presented in the workbook instead.',
  ], WARN),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 9 - alerts
// =====================================================================
children.push(
  H1('Step 9 \u2014 Native drill-down: Alerts'),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Monitor', bold: true }, { text: ' \u2192 ' }, { text: 'Alerts', bold: true }, { text: '.' }]),
  Step(null, [{ text: 'Filter to resource group ' }, { text: 'rg-uoi-iaas', font: 'Consolas', size: 19 }, { text: '.' }]),
  Step(null, [{ text: 'Open one of the alerts named ' }, { text: '\u201CRelated estate alerts correlated into an actionable incident\u201D', bold: true }, { text: ' and show its fired history.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('09-alerts.png', 'Figure 11 \u2014 Azure Monitor Alerts, filtered to rg-uoi-iaas. These are genuinely fired Sev1 alerts from a real alert rule \u2014 not a static image.'),
  SayThis('These alerts genuinely fired. This is a real Azure Monitor alert rule with a real firing history, in the portal, with timestamps you can inspect. This is not a screenshot in a slide deck.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 10 - logs
// =====================================================================
children.push(
  H1('Step 10 \u2014 Native drill-down: Logs'),
  callout('THE STRONGEST CREDIBILITY MOVE AVAILABLE', [
    'Running ad-hoc KQL live is the single most convincing thing you can do, because the audience can ask for anything and watch you answer it against the real workspace. If you rehearse one thing, rehearse this.',
  ], GOOD),
  Spacer(160),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Monitor', bold: true }, { text: ' \u2192 ' }, { text: 'Logs', bold: true }, { text: ', scoped to workspace ' }, { text: 'log-uoi', font: 'Consolas', size: 19 }, { text: '.' }]),
  Step('Run the queries below, live.'),
  Spacer(80),
  H2('What you should see'),
  ...figure('10-logs.png', 'Figure 12 \u2014 Log Analytics. Ad-hoc KQL against the live log-uoi workspace, where the audience can ask for anything.'),
  H2('Query 1 \u2014 prove the correlation number'),
  Code([
    'UoiEstateAlert_CL',
    '| where IsSynthetic == true',
    '| summarize RelatedAlerts = dcount(AlertId) by IncidentId',
  ]),
  Spacer(120),
  Rich([
    { text: 'This returns the headline number from the raw data, in front of the audience. Note the ' },
    { text: 'IsSynthetic == true', font: 'Consolas', size: 19 },
    { text: ' filter \u2014 the labelling is enforced in the data, not just written on a slide. Point at it.' },
  ]),
  H2('Query 2 \u2014 prove the telemetry is real'),
  Code([
    'InsightsMetrics',
    "| where Namespace == 'Processor' and Name == 'UtilizationPercentage'",
    '| summarize avg(Val) by Computer, bin(TimeGenerated, 5m)',
    '| render timechart',
  ]),
  Spacer(120),
  P('This reads the standard Azure Monitor Agent table. There is no synthetic filter here because none is needed \u2014 this data was emitted by the running machines.'),
  H2('Optional \u2014 answer "how does the data get here?"'),
  Rich([
    { text: 'Portal \u2192 ' },
    { text: 'Monitor', bold: true },
    { text: ' \u2192 ' },
    { text: 'Data Collection Rules', bold: true },
    { text: '. Show ' },
    { text: 'dcr-vminsights-uoi', font: 'Consolas', size: 19 },
    { text: ', ' },
    { text: 'dcr-syslog-uoi', font: 'Consolas', size: 19 },
    { text: ' and ' },
    { text: 'dcr-ingest-uoi', font: 'Consolas', size: 19 },
    { text: '. This answers the ingestion question with a resource rather than an architecture diagram.' },
  ]),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 11 - the AI layer
// =====================================================================
children.push(
  H1('Step 11 \u2014 Ask the Observability agent'),
  callout('NOTHING TO DEPLOY \u2014 THIS SHIPS IN THE PORTAL', [
    [{ text: 'There is no Azure OpenAI resource in this demonstration, no model deployment, no key and no endpoint to manage. ', bold: true }, { text: 'The agent is built into the Logs blade. It is the same argument as the rest of the demonstration: the capability is native to the platform the workloads already run on.' }],
  ], GOOD),
  Spacer(160),
  H2('Where to click'),
  Step(null, [{ text: 'Stay in ' }, { text: 'Monitor', bold: true }, { text: ' \u2192 ' }, { text: 'Logs', bold: true }, { text: ' on workspace ' }, { text: 'log-uoi', font: 'Consolas', size: 19 }, { text: '.' }]),
  Step(null, [{ text: 'Click ' }, { text: 'Observability agent', bold: true }, { text: ' in the query toolbar. A chat pane opens on the right.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figureIfExists('agent5-final.png', 'Figure 14 \u2014 The Observability agent answering in the Logs blade. The results grid on the left independently returns 150 for the same incident; the agent agrees, names the earliest signal, and ends with \u201CNo root cause inferred.\u201D Note the \u201CAI-generated content may be incorrect\u201D label the portal adds.'),
  H2('Use this exact prompt'),
  P('Do not improvise this one. The wording carries two protections \u2014 read the warnings below before you use it.'),
  Code([
    'For incident INC-2026-0916-001 in table UoiEstateAlert_CL over the',
    'last 7 days: count DISTINCT AlertId (rows may be ingested more than',
    'once), and name the single earliest signal. Keep the answer to a few',
    'short lines. Synthetic demo data. Do not assert a root cause.',
  ]),
  Spacer(160),
  H2('Warning one \u2014 the agent can contradict your headline'),
  callout('THIS IS THE ONE THAT WILL EMBARRASS YOU', [
    [{ text: 'Tested on the live workspace: asked without the DISTINCT instruction, the agent answered ' }, { text: '\u201CRelated alerts: 300\u201D', bold: true }, { text: ' while the workbook on the previous slide said ' }, { text: '150', bold: true }, { text: '.' }],
    [{ text: 'The agent was not wrong. It counted rows. The seeder had been run twice, so the table held two ingestion batches of 150. The workbook de-duplicates on AlertId and scopes to the newest batch; the agent knows neither rule unless you tell it.' }],
    [{ text: 'Two defences, use both: ', bold: true }, { text: 'keep \u201Ccount DISTINCT AlertId\u201D in the prompt, and seed exactly once on demonstration day.' }],
  ], WARN),
  Spacer(160),
  H2('Warning two \u2014 give it time'),
  Rich([
    { text: 'The agent reasons, writes KQL, runs it, then reconsiders. The scripted prompt above returned in about ' },
    { text: 'a minute and a quarter', bold: true },
    { text: '. A broader, multi-part question took several minutes in testing. Keep the prompt tight, and either narrate the previous slide while it works or ask it before the meeting and return to a finished answer. Do not ask it cold with nothing to say.' },
  ]),
  Spacer(120),
  H2('Verified result'),
  P('Run against the live workspace while preparing this document, the agent returned: 150 distinct AlertId values, earliest signal ALRT-0001 on vm-sql-01 for Document Archive, storage latency on the data tier exceeding 400 ms sustained \u2014 and closed with \u201CNo root cause inferred.\u201D That matches the workbook headline exactly.'),
  Spacer(120),
  H2('Why this lands'),
  Bullet(null, [{ text: 'It shows its work. ', bold: true }, { text: 'Every query it runs is displayed, with the workspace resource ID and the time window. An audience can read the KQL and check it. That is a very different trust proposition from a black box.' }]),
  Bullet(null, [{ text: 'It respects the instruction not to assert a root cause. ', bold: true }, { text: 'In testing it ended with \u201CI\u2019m not attributing a root cause from this summary\u201D. Keep that sentence in the prompt and the AI layer stays inside the same discipline as the rest of the demonstration.' }]),
  Bullet(null, [{ text: 'The portal labels it for you. ', bold: true }, { text: 'The pane carries \u201CAI-generated content may be incorrect\u201D. Point at it rather than hoping nobody reads it \u2014 it reinforces the honesty posture the whole demonstration is built on.' }]),
  Spacer(120),
  SayThis('I have not deployed a model, and there is no AI service in this resource group. This agent is part of Azure Monitor. Notice that it shows me every query it ran, and notice that it declined to assert a root cause \u2014 because I asked it not to. The correlation you saw earlier is deterministic KQL you can audit. This is the layer that helps a responder interpret it.'),
  Spacer(160),
  H2('Optional \u2014 built-in machine learning in KQL'),
  P('If the audience is technical, these are worth 60 seconds. They are built-in Log Analytics functions, require no additional service, and were verified against this estate.'),
  Code([
    '// Unsupervised pattern discovery across the alert set',
    'UoiEstateAlert_CL',
    '| where IsSynthetic == true',
    '| project Service, Tier, Severity, Component',
    '| evaluate autocluster()',
  ]),
  Spacer(120),
  P('Verified result: six discovered segments, including a 35-alert vm-app-02 / Sev2 / app-tier segment, found without being told what to look for.'),
  Code([
    '// Anomaly detection on real CPU telemetry',
    'InsightsMetrics',
    "| where Namespace == 'Processor' and Name == 'UtilizationPercentage'",
    '| make-series CPU=avg(Val) default=0 on TimeGenerated',
    '    from ago(2d) to now() step 15m by Computer',
    '| extend (anom, score, baseline) = series_decompose_anomalies(CPU, 2.0)',
    '| render anomalychart with(anomalycolumns=anom)',
  ]),
  Spacer(120),
  Rich([
    { text: 'Verified result: genuine load excursions on the real virtual machines \u2014 CPU peaks of 50\u201374% against a ~3% average. ' },
    { text: 'Be precise about what this shows: ', bold: true },
    { text: 'it is anomaly detection on real telemetry. It did not detect the synthetic incident, which lives in a different table. Do not conflate the two.' },
  ]),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// STEP 12 - approval gate
// =====================================================================
children.push(
  H1('Step 12 \u2014 The approval gate'),
  P('Approximately 5 minutes. Run this live \u2014 it is the strongest trust moment in the demonstration.'),
  callout('THERE IS NO AUTONOMOUS REMEDIATION', [
    [{ text: 'The gate is enforced in code, not promised in a slide. The runbook fails closed: absent an explicit approval decision, it does nothing.', bold: true }],
    'The runbook simulates remediation. It does not modify the virtual machines in either path.',
  ], GOOD),
  Spacer(160),
  H2('Where to click'),
  Step(null, [{ text: 'Portal \u2192 ' }, { text: 'Automation Accounts', bold: true }, { text: ' \u2192 ' }, { text: 'aa-uoi', font: 'Consolas', size: 19 }, { text: ' \u2192 ' }, { text: 'Runbooks', bold: true }, { text: '.' }]),
  Step(null, [{ text: 'Open ' }, { text: 'Invoke-ApprovedRemediation', bold: true }, { text: '.' }]),
  Spacer(80),
  H2('What you should see'),
  ...figure('11-runbooks.png', 'Figure 13 \u2014 Automation account aa-uoi. The Invoke-ApprovedRemediation runbook \u2014 a real Azure Automation artifact, not a described control.'),
  H2('Run it twice \u2014 the refusal first'),
  callout('ORDER MATTERS', [
    'Demonstrate the refusal before the approval. An audience that has seen the system decline to act believes the approval gate. An audience that has only seen it succeed assumes the gate is decorative.',
  ], TINT),
  Spacer(160),
  Step(null, [{ text: 'Click ' }, { text: 'Start', bold: true }, { text: '. Set ' }, { text: 'ApprovalDecision', font: 'Consolas', size: 19 }, { text: ' = ' }, { text: 'Reject', bold: true }, { text: ' and ' }, { text: 'ApprovedBy', font: 'Consolas', size: 19 }, { text: ' = your name. The runbook records the refusal, changes nothing, and stops.' }]),
  Step(null, [{ text: 'Click ' }, { text: 'Start', bold: true }, { text: ' again. Set ' }, { text: 'ApprovalDecision', font: 'Consolas', size: 19 }, { text: ' = ' }, { text: 'Approve', bold: true }, { text: ' and ' }, { text: 'ApprovedBy', font: 'Consolas', size: 19 }, { text: ' = your name. It walks the simulated remediation steps and writes an audit record.' }]),
  Step(null, [{ text: 'Return to the workbook, ' }, { text: 'Tab 5 \u2014 Response', bold: true }, { text: ', and show the audit trail now containing both entries.' }]),
  Spacer(120),
  Rich([
    { text: 'Both paths write to ' },
    { text: 'UoiRemediationAudit_CL', font: 'Consolas', size: 19 },
    { text: '. The refusal is audited just as carefully as the approval \u2014 that is the point.' },
  ]),
  Spacer(120),
  SayThis('The system proposes. A human decides. Both the approval and the refusal are audited. There is no path through this design where the platform changes your estate because it inferred that it should.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// Q&A
// =====================================================================
children.push(
  H1('Questions you will be asked'),
  H2('\u201CIs this real, or a mock-up?\u201D'),
  P('The virtual machines and their telemetry are real. The business and financial layer is synthetic and labelled as such in the data itself, not just in the presentation. Then open Logs and query it live \u2014 the answer is more convincing demonstrated than asserted.'),
  H2('\u201CDoes correlation prove root cause?\u201D'),
  P('No. Correlation establishes that signals are related and collapses triage volume. It points a responder at the earliest related signal. Determining causation remains a human judgement, and this demonstration is careful not to claim otherwise.'),
  H2('\u201CCan it fix things automatically?\u201D'),
  P('It is deliberately built not to. Remediation requires an explicit human approval decision, and both approvals and refusals are audited. If autonomy is what the customer wants, that is a separate conversation with a separate risk profile.'),
  H2('\u201CWhy not keep using what we already have?\u201D'),
  P('Nothing here says the existing investment was wrong. The argument is consolidation: estate-wide correlation available natively where the workloads already run, with one less integration boundary to maintain and one less place for the data to diverge.'),
  H2('\u201CWhere did the 150 alerts come from?\u201D'),
  Rich([
    { text: 'They are synthetic, generated by ' },
    { text: 'seed-estate.py', font: 'Consolas', size: 19 },
    { text: ' with a fixed random seed so the demonstration is reproducible, and ingested through a real Data Collection Rule into a real Log Analytics custom table. The correlation itself is performed by real KQL against that table. The pipeline is genuine; the alert content is manufactured and labelled.' },
  ]),
  H2('\u201CWhere is the AI in this?\u201D'),
  P('Two places, and it is worth being precise about both. The correlation itself is deterministic KQL \u2014 no model, fully auditable, and it gives the same answer every time. That is a feature, not a gap. The AI layer sits on top: the Observability agent in the Logs blade, which interprets the incident, writes its own queries and shows you every one it ran. There is no Azure OpenAI resource deployed here.'),
  H2('\u201CCan we trust what the agent says?\u201D'),
  P('Treat it as a fast analyst, not an oracle. It shows every query it runs, so its work is checkable. The portal labels its output as possibly incorrect, and so should you. In testing it also produced a materially wrong count when the question was loosely worded \u2014 which is exactly why the prompt in Step 11 is scripted rather than improvised.'),
  H2('\u201CWhat does this cost to run?\u201D'),
  P('This demonstration estate is $17.28 a day in compute \u2014 six Standard_D2ls_v7 virtual machines at $0.12 an hour \u2014 and is deallocated between sessions. That figure describes this demonstration environment only and says nothing about production sizing, which would be driven by the workloads being monitored rather than by six idle simulation hosts.'),
  new Paragraph({ children: [new PageBreak()] })
);

// =====================================================================
// Limitations
// =====================================================================
children.push(
  H1('Deliberate scope and known limitations'),
  P('Disclose these rather than hoping they do not come up. A presenter who names the edges of the demonstration is trusted about everything inside them.'),
  H2('Not included \u2014 documented as production extensions, not built'),
  Bullet('AKS, Azure SQL, Azure AI Search, Event Hubs and Service Bus.'),
  Bullet('Any real Datadog tenant or real on-premises infrastructure.'),
  Bullet(null, [{ text: 'A deployed Azure OpenAI resource. ', bold: true }, { text: 'There is no model deployment, key or endpoint in this estate. The AI in Step 11 is the Observability agent built into the Logs blade, which you consume rather than provision. Everything else in the demonstration works with no AI service at all.' }]),
  Bullet('VM Insights Map and service dependency topology \u2014 the Dependency Agent does not support the Ubuntu builds in this estate.'),
  H2('Operational limitations that affect the demonstration itself'),
  Bullet(null, [{ text: 'Ingestion latency of roughly 10 minutes. ', bold: true }, { text: 'After the virtual machines start, and after a newly created custom table receives its first rows. Zero rows immediately after a successful upload is latency, not failure.' }]),
  Bullet(null, [{ text: 'The synthetic layer ages out. ', bold: true }, { text: 'It is timestamped at seeding time and spans about 45 minutes. Against the workbook\u2019s 24-hour default, data seeded yesterday will be gone. Re-seed on the day you present.' }]),
  Bullet(null, [{ text: 'Log Analytics does not delete data promptly. ', bold: true }, { text: 'Rather than relying on deletion, every seeded query scopes itself to the newest ingestion batch, so repeated seeding cannot inflate the headline number. The audit query deliberately does not do this, so remediation history is retained across runs.' }]),
  Spacer(160),
  H2('Final reminder on language'),
  dataTable(
    ['Do not say', 'Say instead'],
    [
      ['\u201C150 false positives\u201D', '\u201C150 related alerts correlated into 1 actionable incident\u201D'],
      ['\u201CCorrelation shows this caused it\u201D', '\u201CCorrelation shows these signals are related; causation is a human judgement\u201D'],
      ['\u201CAdopting Datadog was a mistake\u201D', '\u201CIt solved the problem they had; the question now is consolidation\u201D'],
      ['\u201CThis is what an outage costs you\u201D', '\u201CIllustrative sample data, not a customer estimate\u201D'],
      ['\u201CIt remediates automatically\u201D', '\u201CIt proposes; a human approves; both decisions are audited\u201D'],
      ['\u201CThe AI found the root cause\u201D', '\u201CThe agent summarised the evidence; it was asked not to infer a cause\u201D'],
      ['\u201CWe deployed AI for this\u201D', '\u201CThe agent is built into Azure Monitor; nothing was deployed\u201D'],
    ],
    [4200, 5160]
  )
);

// =====================================================================
// DOCUMENT
// =====================================================================
const doc = new Document({
  creator: 'Unified Operational Intelligence',
  title: 'Unified Operational Intelligence \u2014 Azure Portal Demonstration Walkthrough',
  description: 'Step-by-step presenter walkthrough with live Azure Portal screenshots. Contains synthetic demo data and illustrative sample financials.',
  styles: {
    default: {
      document: {
        run: { font: 'Arial', size: 21, color: '1A1A1A' },
        paragraph: { spacing: { line: 276 } },
      },
    },
  },
  numbering: {
    config: [
      {
        reference: 'steps',
        levels: [
          {
            level: 0,
            format: LevelFormat.DECIMAL,
            text: '%1.',
            alignment: AlignmentType.START,
            style: {
              paragraph: { indent: { left: convertInchesToTwip(0.4), hanging: convertInchesToTwip(0.25) } },
              run: { bold: true, color: AZ_BLUE },
            },
          },
        ],
      },
      {
        reference: 'bullets',
        levels: [
          {
            level: 0,
            format: LevelFormat.BULLET,
            text: '\u2022',
            alignment: AlignmentType.START,
            style: {
              paragraph: { indent: { left: convertInchesToTwip(0.4), hanging: convertInchesToTwip(0.2) } },
              run: { color: AZ_BLUE },
            },
          },
        ],
      },
    ],
  },
  sections: [
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      footers: {
        default: new Footer({
          children: [
            new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [
                new TextRun({ text: 'Unified Operational Intelligence  \u2014  Synthetic Demo Data  \u2014  Page ', size: 17, color: GREY, font: 'Arial' }),
                new TextRun({ children: [PageNumber.CURRENT], size: 17, color: GREY, font: 'Arial' }),
              ],
            }),
          ],
        }),
      },
      children,
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(OUT, buf);
  console.log('WROTE ' + OUT + ' (' + Math.round(buf.length / 1024) + ' KB)');
});
