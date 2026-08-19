import { useCameraProfiles, useCamerasSeen } from '../api/admin';
import { Dots, Pill, ago } from '../ui';
import { TopBar } from './Layout';

export function Cameras() {
  const q = useCameraProfiles();
  const seen = useCamerasSeen();
  const d = q.data;
  return (
    <>
      <TopBar title="Camera profiles" sub={d ? `${d.generations.length} generations · matrix updated ${d.updatedAt}` : undefined} />
      <div className="content" style={{ gridTemplateColumns: '1fr' }}>
        <div className="scroll">
          <div>
            <div className="mono" style={{ marginBottom: 10 }}>SEEN IN THE WILD · bodies accounts have connected</div>
            {!seen.data ? <Dots /> : seen.data.items.length === 0 ? <p className="muted" style={{ margin: 0, fontSize: 12 }}>No connections reported yet — the app sends model + firmware + slot count once per connection.</p> : (
              <div className="table" style={{ gridTemplateColumns: '160px 120px 100px 90px 120px 120px' }}>
                <div className="th">Model</div><div className="th">Firmware</div><div className="th">Slots</div><div className="th">Users</div><div className="th">Connections</div><div className="th">Last seen</div>
                {seen.data.items.map((c) => (
                  <div key={c.model + c.firmware} style={{ display: 'contents' }}>
                    <div className="td"><span className="name">{c.model}</span></div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>{c.firmware || '—'}</div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>C1–C{c.slots}</div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>{c.users}</div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>{c.connections}</div>
                    <div className="td sub">{c.lastSeen ? `${ago(c.lastSeen)} ago` : '—'}</div>
                  </div>
                ))}
              </div>
            )}
          </div>
          {!d ? <div className="empty"><Dots /></div> : (
            <>
              <div className="table" style={{ gridTemplateColumns: '130px minmax(220px,2fr) 120px 80px 170px minmax(200px,1.5fr)' }}>
                <div className="th">Generation</div><div className="th">Bodies</div><div className="th">Custom slots</div><div className="th">Film sims</div><div className="th">USB write</div><div className="th">Notes</div>
                {d.generations.map((g) => (
                  <div key={g.id} style={{ display: 'contents' }}>
                    <div className="td"><span className="name">{g.id}</span></div>
                    <div className="td wrap" style={{ fontSize: 11.5, color: 'var(--dim)', height: 'auto', minHeight: 52, padding: '10px 12px' }}>{g.bodies.join(' · ')}</div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>C1–C{g.slots}{g.slotsNote && <span className="sub"> {g.slotsNote}</span>}</div>
                    <div className="td" style={{ fontFamily: 'var(--mono)' }}>{g.filmSims}</div>
                    <div className="td">{g.usbWrite === 'full' ? <Pill kind="solid">{g.tested.length ? 'FULL · TESTED' : 'FULL'}</Pill> : g.usbWrite === 'probe' ? <Pill kind="line">PROBE AT CONNECT</Pill> : <Pill kind="dimmed" hollow>READ ONLY</Pill>}</div>
                    <div className="td wrap sub" style={{ height: 'auto', minHeight: 52, padding: '10px 12px' }}>{g.tested.length ? `Verified on ${g.tested.join(', ')}. ` : ''}{g.note ?? ''}</div>
                  </div>
                ))}
              </div>
              <div>
                <div className="mono" style={{ marginBottom: 10 }}>FIELD SUPPORT</div>
                <div className="matrix" style={{ gridTemplateColumns: `220px repeat(${d.generations.length}, minmax(84px, 1fr))` }}>
                  <div className="th">Field</div>{d.generations.map((g) => <div key={g.id} className="th">{g.id}</div>)}
                  {d.fields.map((f) => (
                    <div key={f} style={{ display: 'contents' }}>
                      <div style={{ fontFamily: 'var(--mono)', fontSize: 10.5 }}>{f}</div>
                      {d.generations.map((g) => <div key={g.id + f} className={g.unsupported.includes(f) ? 'no' : 'yes'}>{g.unsupported.includes(f) ? '—' : '●'}</div>)}
                    </div>
                  ))}
                </div>
                <p className="muted" style={{ fontSize: 11.5, maxWidth: 720 }}>Static matrix from the research notes and the app's capability table. The app always derives the real field set from the connected body (<code>GetDeviceInfo</code>) — this page is the reference curators use when reviewing sensor tags.</p>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}
