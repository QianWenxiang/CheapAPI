import { useEffect, useRef } from 'react'

export function MouseRipple() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const ripplesRef = useRef<{ x: number; y: number; r: number; opacity: number; createdAt: number }[]>([])
  const animFrameRef = useRef<number>(0)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let running = true

    const resize = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resize()
    window.addEventListener('resize', resize)

    const handleMouseMove = (e: MouseEvent) => {
      ripplesRef.current.push({
        x: e.clientX,
        y: e.clientY,
        r: 0,
        opacity: 0.45,
        createdAt: Date.now(),
      })
    }
    window.addEventListener('mousemove', handleMouseMove)

    const animate = () => {
      if (!running) return
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      const now = Date.now()
      ripplesRef.current = ripplesRef.current.filter((rip) => {
        const age = now - rip.createdAt
        if (age > 1500) return false
        rip.r = age * 0.12
        rip.opacity = 0.45 * (1 - age / 1500)
        ctx.beginPath()
        ctx.arc(rip.x, rip.y, rip.r, 0, Math.PI * 2)
        ctx.strokeStyle = `rgba(99, 179, 237, ${rip.opacity})`
        ctx.lineWidth = 2
        ctx.stroke()
        return true
      })

      animFrameRef.current = requestAnimationFrame(animate)
    }
    animate()

    return () => {
      running = false
      window.removeEventListener('resize', resize)
      window.removeEventListener('mousemove', handleMouseMove)
      if (animFrameRef.current) cancelAnimationFrame(animFrameRef.current)
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      className='pointer-events-none'
      style={{ position: 'fixed', inset: 0, zIndex: 9999 }}
    />
  )
}